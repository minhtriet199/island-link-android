package io.github.minhtriet199.island_link

import android.content.Context
import android.net.Uri
import android.os.Build
import android.util.Base64
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStream
import java.io.InputStreamReader
import java.net.InetSocketAddress
import java.net.Socket
import java.security.MessageDigest
import java.security.SecureRandom
import java.security.cert.CertificateException
import java.security.cert.X509Certificate
import java.util.UUID
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLSocket
import javax.net.ssl.X509TrustManager

/** What the phone remembers about its PC after pairing (app-private storage). */
data class Pairing(
    val host: String,
    val port: Int,
    val fingerprint: String,
    val pcName: String,
    val id: String,
    val key: String,
) {
    companion object {
        private const val PREFS = "link"

        fun load(ctx: Context): Pairing? {
            val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return Pairing(
                host = p.getString("host", null) ?: return null,
                port = p.getInt("port", 0),
                fingerprint = p.getString("fp", null) ?: return null,
                pcName = p.getString("pc", "") ?: "",
                id = p.getString("id", null) ?: return null,
                key = p.getString("key", null) ?: return null,
            )
        }

        fun clear(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    fun save(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        .putString("host", host).putInt("port", port).putString("fp", fingerprint)
        .putString("pc", pcName).putString("id", id).putString("key", key)
        .apply()
}

/** Thrown when the PC answers with an error the user should see. */
class LinkError(message: String) : Exception(message)

/**
 * One TLS connection to the PC. The PC's certificate is self-signed, so instead of a CA
 * we trust exactly the fingerprint from the pairing QR. Messages are JSON, one per line.
 */
class Connection private constructor(private val socket: SSLSocket) : AutoCloseable {
    private val reader = BufferedReader(InputStreamReader(socket.inputStream, Charsets.UTF_8))
    private val out = socket.outputStream

    fun send(msg: JSONObject) = synchronized(out) {
        out.write((msg.toString() + "\n").toByteArray(Charsets.UTF_8))
        out.flush()
    }

    /** Next message, or null when the PC closed the link. Throws SocketTimeoutException after [timeoutMs]. */
    fun receive(timeoutMs: Int): JSONObject? {
        socket.soTimeout = timeoutMs
        return reader.readLine()?.let(::JSONObject)
    }

    /**
     * Streams one file after a {"t":"file"} header and waits for the PC to confirm.
     * Returns the name the PC saved it under (it may add " (2)").
     */
    fun sendFile(name: String, size: Long, input: InputStream, onProgress: (sent: Long) -> Unit): String {
        synchronized(out) {
            out.write((JSONObject().put("t", "file").put("name", name).put("size", size).toString() + "\n")
                .toByteArray(Charsets.UTF_8))
            val buf = ByteArray(64 * 1024)
            var sent = 0L
            while (sent < size) {
                val n = input.read(buf, 0, minOf(buf.size.toLong(), size - sent).toInt())
                if (n < 0) throw LinkError("$name got shorter while sending.")
                out.write(buf, 0, n)
                sent += n
                onProgress(sent)
            }
            out.flush()
        }
        val reply = receive(SAVE_TIMEOUT_MS) ?: throw LinkError("The PC closed the connection.")
        if (reply.optString("t") != "saved") throw LinkError(reply.optString("msg", "The PC didn't save $name."))
        return reply.optString("name", name)
    }

    override fun close() = runCatching { socket.close() }.let { }

    companion object {
        private const val CONNECT_TIMEOUT_MS = 5_000
        private const val SAVE_TIMEOUT_MS = 60_000

        fun open(host: String, port: Int, fingerprint: String): Connection {
            val tls = SSLContext.getInstance("TLSv1.3")
            tls.init(null, arrayOf(PinnedTrust(fingerprint)), SecureRandom())
            val raw = Socket().apply {
                tcpNoDelay = true // touchpad moves shouldn't wait to fill a packet
                connect(InetSocketAddress(host, port), CONNECT_TIMEOUT_MS)
            }
            val socket = tls.socketFactory.createSocket(raw, host, port, true) as SSLSocket
            socket.soTimeout = CONNECT_TIMEOUT_MS
            socket.startHandshake()
            return Connection(socket)
        }

        /** First contact: send the one-time token from the QR, get back the PC's welcome. */
        fun pair(ctx: Context, qr: String): Pairing {
            val uri = Uri.parse(qr)
            if (uri.scheme != "islandlink" || uri.host != "pair") throw LinkError("That's not an Island Link code.")
            val host = uri.getQueryParameter("h") ?: throw LinkError("The code is missing the PC address.")
            val port = uri.getQueryParameter("p")?.toIntOrNull() ?: throw LinkError("The code is missing the port.")
            val fp = uri.getQueryParameter("fp") ?: throw LinkError("The code is missing the PC's fingerprint.")
            val token = uri.getQueryParameter("t") ?: throw LinkError("The code is missing its token.")

            val id = UUID.randomUUID().toString()
            val key = ByteArray(32).also { SecureRandom().nextBytes(it) }
                .let { Base64.encodeToString(it, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP) }

            open(host, port, fp).use { c ->
                c.send(JSONObject().put("t", "pair").put("token", token).put("id", id).put("key", key)
                    .put("name", Build.MODEL))
                val reply = c.receive(CONNECT_TIMEOUT_MS) ?: throw LinkError("The PC closed the connection.")
                if (reply.optString("t") != "welcome") throw LinkError(reply.optString("msg", "Pairing failed."))
                return Pairing(host, port, fp, reply.optString("pc", uri.getQueryParameter("n") ?: "PC"), id, key)
                    .also { it.save(ctx) }
            }
        }
    }
}

/** Accepts the PC only if its certificate's SHA-256 matches the paired fingerprint. */
private class PinnedTrust(private val fingerprint: String) : X509TrustManager {
    override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {
        val sum = MessageDigest.getInstance("SHA-256").digest(chain.first().encoded)
        val hex = sum.joinToString("") { "%02x".format(it) }
        if (!MessageDigest.isEqual(hex.toByteArray(), fingerprint.lowercase().toByteArray())) {
            throw CertificateException("This isn't the PC you paired with.")
        }
    }

    override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) =
        throw CertificateException("client certificates are not used")

    override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
}
