package io.github.minhtriet199.island_link

import android.app.Notification
import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONObject

/**
 * Passes phone notifications to the PC, where Island shows them as bubbles. Android starts this
 * only after you allow it in its settings. Skips what isn't really a message: ongoing ones
 * (music, downloads), group summaries and this app's own.
 */
class NotifyListener : NotificationListenerService() {
    private val seen = object : LinkedHashMap<String, Int>() { // an update re-posts the same text
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Int>) = size > MAX_SEEN
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!isOn(this) || sbn.packageName == packageName) return
        val n = sbn.notification
        if (!sbn.isClearable || n.flags and Notification.FLAG_GROUP_SUMMARY != 0 || n.category in SKIP) return
        val title = n.extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = (n.extras.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: n.extras.getCharSequence(Notification.EXTRA_TEXT))
            ?.toString().orEmpty()
        if (title.isEmpty() && text.isEmpty()) return
        val hash = (title + text).hashCode()
        if (seen[sbn.key] == hash) return
        seen[sbn.key] = hash
        LinkService.current?.send(
            JSONObject().put("t", "notif").put("app", appName(sbn)).put("title", title).put("text", text.take(MAX_TEXT))
        )
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        seen.remove(sbn.key)
    }

    private fun appName(sbn: StatusBarNotification): String {
        val info = if (Build.VERSION.SDK_INT >= 33) {
            sbn.notification.extras.getParcelable(APP_INFO, ApplicationInfo::class.java)
        } else {
            @Suppress("DEPRECATION") sbn.notification.extras.getParcelable(APP_INFO)
        }
        return info?.loadLabel(packageManager)?.toString() ?: sbn.packageName
    }

    companion object {
        private const val PREFS = "settings"
        private const val APP_INFO = "android.appInfo" // Android adds this to every notification
        private const val MAX_SEEN = 64
        private const val MAX_TEXT = 2_000
        private val SKIP = setOf(
            Notification.CATEGORY_SERVICE, Notification.CATEGORY_PROGRESS, Notification.CATEGORY_TRANSPORT,
            Notification.CATEGORY_SYSTEM, Notification.CATEGORY_STATUS,
        )

        fun isOn(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("alerts", true)
        fun setOn(ctx: Context, on: Boolean) =
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean("alerts", on).apply()
    }
}
