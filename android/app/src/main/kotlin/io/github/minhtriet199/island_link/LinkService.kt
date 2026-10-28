package io.github.minhtriet199.island_link

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import org.json.JSONObject
import java.net.SocketTimeoutException

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

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val pairing = Pairing.load(this)
        if (pairing == null) {
            publish(LinkStatus.UNPAIRED, null, null)
            stopSelf()
            return START_NOT_STICKY
        }
        startInForeground(notification(getString(R.string.link_connecting, pairing.pcName)))
        if (worker?.isAlive != true) {
            running = true
            worker = Thread({ loop(pairing) }, "island-link").apply { start() }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        connection?.close()
        worker?.interrupt()
        if (Pairing.load(this) != null) publish(LinkStatus.OFFLINE, null, null)
        super.onDestroy()
    }

    /** Connect, say hello, keep pinging; on any drop wait a bit longer each time and retry. */
    private fun loop(pairing: Pairing) {
        var backoffMs = 1_000L
        while (running) {
            publish(LinkStatus.CONNECTING, pairing.pcName, null)
            try {
                Connection.open(pairing.host, pairing.port, pairing.fingerprint).use { c ->
                    connection = c
                    c.send(JSONObject().put("t", "hello").put("id", pairing.id).put("key", pairing.key))
                    val reply = c.receive(HELLO_TIMEOUT_MS) ?: throw LinkError("The PC closed the connection.")
                    if (reply.optString("t") != "welcome") {
                        if (reply.optString("msg") == "unpaired") return forgotten()
                        throw LinkError(reply.optString("msg", "The PC said no."))
                    }
                    publish(LinkStatus.CONNECTED, reply.optString("pc", pairing.pcName), null)
                    backoffMs = 1_000L
                    talk(c)
                }
            } catch (e: Exception) {
                if (!running) return
                publish(LinkStatus.OFFLINE, pairing.pcName, e.message)
            } finally {
                connection = null
            }
            try {
                Thread.sleep(backoffMs)
            } catch (_: InterruptedException) {
                return
            }
            backoffMs = (backoffMs * 2).coerceAtMost(MAX_BACKOFF_MS)
        }
    }

    /** Read until the link drops. A quiet link gets a ping; no answer for a while means it's gone. */
    private fun talk(c: Connection) {
        var lastHeard = System.currentTimeMillis()
        while (running) {
            val msg = try {
                c.receive(PING_EVERY_MS) ?: return
            } catch (_: SocketTimeoutException) {
                if (System.currentTimeMillis() - lastHeard > DEAD_AFTER_MS) return
                c.send(JSONObject().put("t", "ping"))
                continue
            }
            lastHeard = System.currentTimeMillis()
            when (msg.optString("t")) {
                "pong" -> Unit
                // later steps: notifications, download progress, terminal
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
        private const val PING_EVERY_MS = 25_000
        private const val DEAD_AFTER_MS = 70_000L
        private const val MAX_BACKOFF_MS = 30_000L

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

    fun post(status: LinkStatus, pc: String?, error: String?) {
        val event = mapOf("status" to status.name.lowercase(), "pc" to pc, "error" to error)
        last = event
        main.post { listener?.invoke(event) }
    }
}
