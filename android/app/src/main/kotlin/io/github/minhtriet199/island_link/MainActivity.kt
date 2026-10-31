package io.github.minhtriet199.island_link

import android.Manifest
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.Executors

/**
 * Bridge between the Flutter UI and the native link (see lib/link.dart):
 *   island_link/link    methods: status, pair(uri), start, forget, pickFiles, send(json), lastDownload,
 *                       terminalAllowed, alertsAccess, openAlertsAccess, alertsOn, setAlertsOn, authenticate
 *   island_link/status  stream of {status, pc, error}
 *   island_link/msg     stream of the PC's messages (JSON text) while the app is open
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
                "send" -> result.success(LinkService.current?.send(JSONObject(call.arguments as String)) ?: false)
                "lastDownload" -> result.success(LinkEvents.lastDownload)
                "terminalAllowed" -> result.success(LinkEvents.terminal)
                "alertsAccess" -> result.success(alertsAccess())
                "openAlertsAccess" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                "alertsOn" -> result.success(NotifyListener.isOn(this))
                "setAlertsOn" -> {
                    NotifyListener.setOn(this, call.arguments as Boolean)
                    result.success(null)
                }
                "authenticate" -> authenticate(call.arguments as String) { result.success(it) }
                "forget" -> {
                    LinkService.stop(this)
                    Pairing.clear(this)
                    LinkEvents.post(LinkStatus.UNPAIRED, null, null)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "island_link/msg").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                LinkEvents.messages = { sink.success(it) }
            }

            override fun onCancel(arguments: Any?) {
                LinkEvents.messages = null
            }
        })

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
        LinkEvents.messages = null
        io.shutdown()
        super.onDestroy()
    }

    private fun alertsAccess(): Boolean {
        val mine = ComponentName(this, NotifyListener::class.java).flattenToString()
        return Settings.Secure.getString(contentResolver, "enabled_notification_listeners")?.contains(mine) == true
    }

    /** Fingerprint (or the screen lock) before anything sensitive. Fails closed where it can't ask. */
    private fun authenticate(reason: String, done: (Boolean) -> Unit) {
        if (Build.VERSION.SDK_INT < 28) return done(false)
        val builder = BiometricPrompt.Builder(this).setTitle(reason)
        if (Build.VERSION.SDK_INT >= 30) {
            builder.setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.DEVICE_CREDENTIAL
            )
        } else {
            @Suppress("DEPRECATION") builder.setDeviceCredentialAllowed(true)
        }
        var answered = false
        fun once(ok: Boolean) {
            if (!answered) {
                answered = true
                done(ok)
            }
        }
        builder.build().authenticate(CancellationSignal(), mainExecutor, object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) = once(true)
            override fun onAuthenticationError(code: Int, message: CharSequence) = once(false)
        })
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
