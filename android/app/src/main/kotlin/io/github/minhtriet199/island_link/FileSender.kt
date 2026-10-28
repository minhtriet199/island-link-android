package io.github.minhtriet199.island_link

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import org.json.JSONObject
import java.io.File
import java.io.InputStream
import java.util.concurrent.Executors

/**
 * Sends files to the PC on their own connection, one batch at a time, with a progress
 * notification. Runs inside [LinkService] so a long upload survives leaving the app.
 */
class FileSender(private val ctx: Context) {
    private val queue = Executors.newSingleThreadExecutor()
    private val notifications = ctx.getSystemService(NotificationManager::class.java)

    fun send(uris: List<Uri>) {
        if (uris.isNotEmpty()) queue.execute { sendBatch(uris) }
    }

    fun shutdown() = queue.shutdown()

    private fun sendBatch(uris: List<Uri>) {
        val pairing = Pairing.load(ctx) ?: return
        val files = uris.mapNotNull(::describe)
        val total = files.sumOf { it.size }.coerceAtLeast(1)
        var done = 0L
        var lastPercent = -1

        fun show(text: String, percent: Int?) {
            notifications.notify(NOTIFICATION_ID, notification(text, percent))
        }

        show(ctx.getString(R.string.files_sending, files.size, pairing.pcName), 0)
        try {
            Connection.open(pairing.host, pairing.port, pairing.fingerprint).use { c ->
                c.send(JSONObject().put("t", "hello").put("id", pairing.id).put("key", pairing.key)
                    .put("purpose", "files"))
                val reply = c.receive(HELLO_TIMEOUT_MS) ?: throw LinkError("The PC closed the connection.")
                if (reply.optString("t") != "welcome") throw LinkError(reply.optString("msg", "The PC said no."))

                for (f in files) {
                    f.open().use { input ->
                        c.sendFile(f.name, f.size, input) { sent ->
                            val percent = ((done + sent) * 100 / total).toInt()
                            if (percent != lastPercent) { // don't flood the notification shade
                                lastPercent = percent
                                show(ctx.getString(R.string.files_sending_one, f.name), percent)
                            }
                        }
                    }
                    done += f.size
                    f.cleanup()
                }
            }
            show(ctx.resources.getQuantityString(R.plurals.files_sent, files.size, files.size, pairing.pcName), null)
        } catch (e: Exception) {
            files.forEach { it.cleanup() }
            show(ctx.getString(R.string.files_failed, e.message ?: e.javaClass.simpleName), null)
        }
    }

    /** Name, size and a way to read one shared item. Unknown sizes are copied to cache first. */
    private class Item(val name: String, val size: Long, val open: () -> InputStream, val temp: File? = null) {
        fun cleanup() {
            temp?.delete()
        }
    }

    private fun describe(uri: Uri): Item? = runCatching {
        val resolver = ctx.contentResolver
        var name = uri.lastPathSegment ?: "file"
        var size = -1L
        resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use {
            if (it.moveToFirst()) {
                it.getString(0)?.let { n -> name = n }
                if (!it.isNull(1)) size = it.getLong(1)
            }
        }
        if (size >= 0) {
            Item(name, size, { resolver.openInputStream(uri) ?: throw LinkError("Can't open $name.") })
        } else {
            val temp = File.createTempFile("share", null, ctx.cacheDir)
            resolver.openInputStream(uri)!!.use { input -> temp.outputStream().use { input.copyTo(it) } }
            Item(name, temp.length(), { temp.inputStream() }, temp)
        }
    }.getOrNull()

    private fun notification(text: String, percent: Int?): Notification {
        if (notifications.getNotificationChannel(CHANNEL) == null) {
            notifications.createNotificationChannel(
                NotificationChannel(CHANNEL, ctx.getString(R.string.files_channel), NotificationManager.IMPORTANCE_LOW)
            )
        }
        return Notification.Builder(ctx, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_leaf)
            .setContentTitle(ctx.getString(R.string.app_name))
            .setContentText(text)
            .setOngoing(percent != null)
            .apply { if (percent != null) setProgress(100, percent, false) }
            .build()
    }

    companion object {
        private const val CHANNEL = "files"
        private const val NOTIFICATION_ID = 2
        private const val HELLO_TIMEOUT_MS = 5_000
        const val ACTION_SEND = "io.github.minhtriet199.island_link.SEND_FILES"

        /** Hands files to the link service, passing on permission to read them. */
        fun start(ctx: Context, uris: List<Uri>) {
            if (uris.isEmpty()) return
            val intent = Intent(ctx, LinkService::class.java).setAction(ACTION_SEND)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            intent.clipData = ClipData.newRawUri("files", uris.first()).apply {
                uris.drop(1).forEach { addItem(ClipData.Item(it)) }
            }
            ctx.startForegroundService(intent)
        }

        fun urisOf(intent: Intent): List<Uri> {
            val clip = intent.clipData ?: return listOfNotNull(intent.data)
            return (0 until clip.itemCount).mapNotNull { clip.getItemAt(it).uri }
        }
    }
}
