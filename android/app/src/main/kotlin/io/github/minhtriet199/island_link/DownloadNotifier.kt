package io.github.minhtriet199.island_link

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import org.json.JSONObject

/**
 * The PC's Download mode as a real progress-bar notification with buttons, updated from the state
 * Island sends every few seconds. A bigger one pops up when the PC is about to shut down.
 */
class DownloadNotifier(private val service: LinkService) {
    private val nm = service.getSystemService(NotificationManager::class.java)
    private var active = false
    private var lastShown = ""

    fun update(s: JSONObject) {
        val pc = Pairing.load(service)?.pcName ?: "PC"
        when {
            s.optBoolean("asking") -> asking(s, pc)
            s.optBoolean("on") -> progress(s, pc)
            active -> {
                clear()
                if (s.optInt("quiet") >= FINISHED_AFTER_S) done() // otherwise you stopped it yourself
            }
        }
    }

    fun clear() {
        active = false
        lastShown = ""
        nm.cancel(ID)
    }

    private fun progress(s: JSONObject, pc: String) {
        val items = s.optJSONArray("items")
        var done = 0.0
        var total = 0.0
        var name = ""
        for (i in 0 until (items?.length() ?: 0)) {
            val it = items!!.getJSONObject(i)
            done += it.optDouble("done", 0.0)
            total += it.optDouble("total", 0.0)
            if (name.isEmpty()) name = it.optString("name")
        }
        val percent = if (total > 0) (done * 100 / total).toInt().coerceIn(0, 100) else -1
        val speed = s.optDouble("speed", 0.0)
        val text = when {
            name.isNotEmpty() -> listOfNotNull(name, "$percent%".takeIf { percent >= 0 }, rate(speed)).joinToString(" · ")
            !s.optBoolean("saw") -> service.getString(R.string.dl_waiting)
            speed > BUSY_BYTES_S -> rate(speed)
            else -> service.getString(R.string.dl_finishing)
        }
        val keep = s.optString("after") == "keep"
        val key = "$text|$keep"
        if (key == lastShown) return
        lastShown = key
        active = true
        nm.notify(ID, builder(CHANNEL, Notification.PRIORITY_LOW)
            .setContentTitle(service.getString(R.string.dl_title, pc))
            .setContentText(text)
            .setOngoing(true)
            .setProgress(100, percent.coerceAtLeast(0), percent < 0)
            .addAction(action(R.string.dl_stop, "dl.stop"))
            .addAction(
                if (keep) action(R.string.dl_then_keep, "dl.after-shutdown")
                else action(R.string.dl_then_shutdown, "dl.after-keep")
            )
            .build())
    }

    private fun asking(s: JSONObject, pc: String) {
        val left = s.optInt("countdown")
        active = true
        nm.notify(ID, builder(ALERT_CHANNEL, Notification.PRIORITY_HIGH)
            .setContentTitle(service.getString(R.string.dl_done))
            .setContentText(service.getString(R.string.dl_asking, pc, "%d:%02d".format(left / 60, left % 60)))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(action(R.string.dl_keep, "dl.keep"))
            .addAction(action(R.string.dl_shutdown, "dl.shutdown"))
            .build())
    }

    private fun done() {
        nm.notify(ID, builder(CHANNEL, Notification.PRIORITY_LOW).setContentTitle(service.getString(R.string.dl_done)).setAutoCancel(true).build())
    }

    @Suppress("DEPRECATION") // priority only matters below Android 8's channels; harmless above
    private fun builder(channel: String, priority: Int): Notification.Builder {
        if (nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL, service.getString(R.string.dl_channel), NotificationManager.IMPORTANCE_LOW))
            nm.createNotificationChannel(NotificationChannel(ALERT_CHANNEL, service.getString(R.string.dl_alert_channel), NotificationManager.IMPORTANCE_HIGH))
        }
        val open = PendingIntent.getActivity(service, 0, Intent(service, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        return Notification.Builder(service, channel).setSmallIcon(R.drawable.ic_stat_leaf).setContentIntent(open).setPriority(priority)
    }

    private fun action(label: Int, what: String): Notification.Action {
        val intent = Intent(service, LinkService::class.java).setAction(LinkService.ACTION_DO).putExtra(LinkService.EXTRA_WHAT, what)
        val pending = PendingIntent.getService(service, what.hashCode(), intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        return Notification.Action.Builder(null, service.getString(label), pending).build()
    }

    private fun rate(b: Double) = if (b >= 1 shl 20) "%.1f MB/s".format(b / (1 shl 20)) else "${(b / 1024).toInt()} KB/s"

    companion object {
        private const val ID = 3
        private const val CHANNEL = "download"
        private const val ALERT_CHANNEL = "download-alert"
        private const val FINISHED_AFTER_S = 60
        private const val BUSY_BYTES_S = 150_000
    }
}
