package io.github.minhtriet199.island_link

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.Toast

/**
 * Invisible target for Android's Share sheet: "Share → Island Link" from any app.
 * It hands the files to the link service and closes right away.
 */
class ShareActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val pairing = Pairing.load(this)
        val uris = sharedUris(intent)
        when {
            pairing == null -> toast(getString(R.string.files_not_paired))
            uris.isEmpty() -> toast(getString(R.string.files_nothing))
            else -> {
                FileSender.start(this, uris)
                toast(getString(R.string.files_sending, uris.size, pairing.pcName))
            }
        }
        finish()
    }

    private fun toast(text: String) = Toast.makeText(this, text, Toast.LENGTH_SHORT).show()

    @Suppress("DEPRECATION") // the typed getParcelable* overloads need API 33; minSdk is 26
    private fun sharedUris(intent: Intent): List<Uri> = when (intent.action) {
        Intent.ACTION_SEND -> listOfNotNull(intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri)
        Intent.ACTION_SEND_MULTIPLE ->
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM).orEmpty()
        else -> emptyList()
    }
}
