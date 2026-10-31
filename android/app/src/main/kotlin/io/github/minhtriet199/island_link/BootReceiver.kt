package io.github.minhtriet199.island_link

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Brings the link back after a phone restart or an app update, without opening the app. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Pairing.load(context) != null) LinkService.start(context)
    }
}
