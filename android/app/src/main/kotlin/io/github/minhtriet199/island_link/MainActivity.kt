package io.github.minhtriet199.island_link

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Bridge between the Flutter UI and the native link (see lib/link.dart):
 *   island_link/link    methods: status, pair(uri), start, forget
 *   island_link/status  stream of {status, pc, error}
 */
class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()

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
}
