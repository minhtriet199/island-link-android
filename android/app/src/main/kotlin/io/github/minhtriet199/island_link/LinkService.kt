package io.github.minhtriet199.island_link

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.Network
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import org.json.JSONObject
import java.net.SocketTimeoutException
import java.util.concurrent.Executors

/** Link state the Flutter UI shows. */
enum class LinkStatus { UNPAIRED, CONNECTING, CONNECTED, OFFLINE }

/**
 * Keeps the one connection to the PC alive while the app is closed. Android requires a
 * foreground service (with its small permanent notification) for that. The Flutter UI is
 * not needed here, so its engine only runs while the app is open.
 */
class LinkService : Service() {
    @Volatile private var running = false
    @Volatile private var connection: Connection? = null
    private var worker: Thread? = null
    @Volatile private var sleeping = false
    @Volatile private var statusText: String? = null // a repeat start must not turn "Connected" back into "Looking"
    private val files by lazy { FileSender(this) }
    private val downloads by lazy { DownloadNotifier(this) }
    private val outbox = Executors.newSingleThreadExecutor() // sockets can't be written on the UI thread
    private val watching = java.util.concurrent.ConcurrentHashMap.newKeySet<String>()
    @Volatile private var batteryLevel = -1
    @Volatile private var batteryCharging = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        current = this
        registerReceiver(batteryChanged, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        getSystemService(ConnectivityManager::class.java).registerDefaultNetworkCallback(networkBack)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val pairing = Pairing.load(this)
        if (pairing == null) {
            publish(LinkStatus.UNPAIRED, null, null)
            stopSelf()
            return START_NOT_STICKY
        }
        startInForeground(notification(statusText ?: getString(R.string.link_connecting, pairing.pcName)))
        if (worker?.isAlive != true) {
            running = true
            worker = Thread({ loop(pairing) }, "island-link").apply { start() }
        }
        when (intent?.action) {
            FileSender.ACTION_SEND -> files.send(FileSender.urisOf(intent))
            ACTION_DO -> intent.getStringExtra(EXTRA_WHAT)?.let { send(JSONObject().put("t", "do").put("what", it)) }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        current = null
        unregisterReceiver(batteryChanged)
        getSystemService(ConnectivityManager::class.java).unregisterNetworkCallback(networkBack)
        connection?.close()
        worker?.interrupt()
        files.shutdown()
        outbox.shutdown()
        downloads.clear()
        if (Pairing.load(this) != null) publish(LinkStatus.OFFLINE, null, null)
        super.onDestroy()
    }

    /** Queues one message to the PC; false when there's no link right now. */
    fun send(msg: JSONObject): Boolean {
        if (msg.optString("t") == "watch") {
            if (msg.optBoolean("on")) watching.add(msg.optString("what")) else watching.remove(msg.optString("what"))
        }
        val c = connection ?: return false
        outbox.execute { runCatching { c.send(msg) } }
        return true
    }

    private val batteryChanged = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
            val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) * 100 / scale
            val charging = intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) != 0
            if (level != batteryLevel || charging != batteryCharging) { // it fires far more often than this changes
                batteryLevel = level
                batteryCharging = charging
                sendBattery()
            }
        }
    }

    private fun sendBattery() {
        if (batteryLevel >= 0) send(JSONObject().put("t", "battery").put("level", batteryLevel).put("charging", batteryCharging))
    }

    /** The network came back: try now instead of finishing the backoff (timers pause while the phone sleeps). */
    private val networkBack = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            if (sleeping) worker?.interrupt()
        }
    }

    /** Connect, say hello, listen; on any drop wait a bit longer each time and retry. */
    private fun loop(pairing: Pairing) {
        var backoffMs = 1_000L
        while (running) {
            publish(LinkStatus.CONNECTING, pairing.pcName, null)
            try {
                Connection.open(pairing.host, pairing.port, pairing.fingerprint).use { c ->
                    c.send(JSONObject().put("t", "hello").put("id", pairing.id).put("key", pairing.key))
                    val reply = c.receive(HELLO_TIMEOUT_MS) ?: throw LinkError("The PC closed the connection.")
                    if (reply.optString("t") != "welcome") {
                        if (reply.optString("msg") == "unpaired") return forgotten()
                        throw LinkError(reply.optString("msg", "The PC said no."))
                    }
                    connection = c // only now: nothing else may reach the PC before the hello
                    LinkEvents.terminal = reply.optBoolean("terminal")
                    publish(LinkStatus.CONNECTED, reply.optString("pc", pairing.pcName), null)
                    backoffMs = 1_000L
                    sendBattery()
                    watching.forEach { send(JSONObject().put("t", "watch").put("what", it).put("on", true)) }
                    talk(c)
                }
            } catch (e: Exception) {
                if (!running) return
                publish(LinkStatus.OFFLINE, pairing.pcName, e.message)
            } finally {
                connection = null
            }
            try {
                sleeping = true
                Thread.sleep(backoffMs)
            } catch (_: InterruptedException) {
                if (!running) return
            } finally {
                sleeping = false
            }
            backoffMs = (backoffMs * 2).coerceAtMost(MAX_BACKOFF_MS)
        }
    }

    /**
     * Read until the link drops. The PC pings every 30 s: its packet wakes this phone from deep sleep, where
     * a timer here wouldn't fire. Hearing nothing for [DEAD_AFTER_MS] means the link is gone.
     */
    private fun talk(c: Connection) {
        while (running) {
            val msg = try {
                c.receive(DEAD_AFTER_MS) ?: return
            } catch (_: SocketTimeoutException) {
                return
            }
            when (msg.optString("t")) {
                "ping" -> send(JSONObject().put("t", "pong"))
                "pong" -> Unit
                "error" -> if (msg.optString("msg") == "unpaired") return forgotten()
                "dl" -> {
                    LinkEvents.lastDownload = msg.toString()
                    LinkEvents.message(msg.toString())
                    downloads.update(msg.getJSONObject("s"))
                }
                "config" -> {
                    LinkEvents.terminal = msg.optBoolean("terminal")
                    LinkEvents.message(msg.toString())
                }
                else -> LinkEvents.message(msg.toString())
            }
        }
    }

    /** The PC no longer knows this phone (it was removed there): drop the pairing. */
    private fun forgotten() {
        Pairing.clear(this)
        running = false
        publish(LinkStatus.UNPAIRED, null, getString(R.string.link_forgotten))
        stopSelf()
    }

    private fun publish(status: LinkStatus, pc: String?, error: String?) {
        LinkEvents.post(status, pc, error)
        if (status == LinkStatus.UNPAIRED || !running) return
        val text = when (status) {
            LinkStatus.CONNECTED -> getString(R.string.link_connected, pc)
            LinkStatus.CONNECTING -> getString(R.string.link_connecting, pc)
            else -> getString(R.string.link_offline, pc)
        }
        statusText = text
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification(text))
    }

    private fun startInForeground(n: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        } else {
            startForeground(NOTIFICATION_ID, n)
        }
    }

    private fun notification(text: String): Notification {
        val nm = getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, getString(R.string.link_channel), NotificationManager.IMPORTANCE_MIN)
            )
        }
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE
        )
        return Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_leaf)
            .setContentTitle(getString(R.string.app_name))
            .setContentText(text)
            .setContentIntent(open)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL = "link"
        private const val NOTIFICATION_ID = 1
        private const val HELLO_TIMEOUT_MS = 5_000
        private const val DEAD_AFTER_MS = 70_000
        private const val MAX_BACKOFF_MS = 30_000L

        const val ACTION_DO = "io.github.minhtriet199.island_link.DO"
        const val EXTRA_WHAT = "what"

        /** The running service, for the notification listener and the UI. */
        @Volatile var current: LinkService? = null
            private set

        fun start(ctx: Context) = ctx.startForegroundService(Intent(ctx, LinkService::class.java))
        fun stop(ctx: Context) = ctx.stopService(Intent(ctx, LinkService::class.java))
    }
}

/** Last known link state, pushed to whoever listens (the Flutter UI while it's open). */
object LinkEvents {
    private val main = Handler(Looper.getMainLooper())
    @Volatile var last: Map<String, Any?> = mapOf("status" to LinkStatus.UNPAIRED.name.lowercase())
        private set
    var listener: ((Map<String, Any?>) -> Unit)? = null
    var messages: ((String) -> Unit)? = null
    @Volatile var lastDownload: String? = null
    @Volatile var terminal = false

    /** A message from the PC for the open Flutter screen, as JSON text. */
    fun message(json: String) {
        main.post { messages?.invoke(json) }
    }

    fun post(status: LinkStatus, pc: String?, error: String?) {
        val event = mapOf("status" to status.name.lowercase(), "pc" to pc, "error" to error)
        last = event
        main.post { listener?.invoke(event) }
    }
}
