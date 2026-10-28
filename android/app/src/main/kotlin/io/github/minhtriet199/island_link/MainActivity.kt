package io.github.minhtriet199.island_link

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Bridge between the Flutter UI and the native link (see lib/link.dart):
 *   island_link/link    methods: status, pair(uri), start, forget, pickFiles
 *   island_link/status  stream of {status, pc, error}
 */
class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()
    private var pickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        val messenger = engine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "island_link/link").setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(currentStatus())
                "pair" -> io.execute {
                    try {
                        val pairing = Connection.pair(this, call.arguments as String)
                        LinkEvents.post(LinkStatus.CONNECTING, pairing.pcName, null)
                        runOnUiThread {
                            startLink()
                            result.success(pairing.pcName)
                        }
                    } catch (e: Exception) {
                        val msg = (e as? LinkError)?.message ?: getString(R.string.link_pair_failed)
                        runOnUiThread { result.error("pair", msg, e.message) }
                    }
                }
                "start" -> {
                    if (Pairing.load(this) != null) startLink()
                    result.success(null)
                }
                "pickFiles" -> {
                    pickResult?.success(0) // a second tap replaces a picker that never answered
                    pickResult = result
                    startActivityForResult(
                        Intent(Intent.ACTION_OPEN_DOCUMENT)
                            .addCategory(Intent.CATEGORY_OPENABLE)
                            .setType("*/*")
                            .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true),
                        PICK_FILES,
                    )
                }
                "forget" -> {
                    LinkService.stop(this)
                    Pairing.clear(this)
                    LinkEvents.post(LinkStatus.UNPAIRED, null, null)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "island_link/status").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                LinkEvents.listener = { sink.success(it) }
                sink.success(currentStatus())
            }

            override fun onCancel(arguments: Any?) {
                LinkEvents.listener = null
            }
        })
    }

    /** Files picked from the Files icon go to the PC like shared ones. Replies with how many. */
    @Deprecated("FlutterActivity is not a ComponentActivity, so no ActivityResult API here")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_FILES) return
        val uris = if (resultCode == RESULT_OK && data != null) FileSender.urisOf(data) else emptyList()
        FileSender.start(this, uris)
        pickResult?.success(uris.size)
        pickResult = null
    }

    override fun onDestroy() {
        LinkEvents.listener = null
        io.shutdown()
        super.onDestroy()
    }

    /** Paired but the service hasn't reported yet → show the PC name while it connects. */
    private fun currentStatus(): Map<String, Any?> {
        val pairing = Pairing.load(this) ?: return mapOf("status" to "unpaired")
        val last = LinkEvents.last
        return if (last["status"] == "unpaired") mapOf("status" to "connecting", "pc" to pairing.pcName) else last
    }

    /** The link's notification needs permission on Android 13+; ask once, the link runs either way. */
    private fun startLink() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
        LinkService.start(this)
    }

    companion object {
        private const val PICK_FILES = 7
    }
}
