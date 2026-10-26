package dev.rishithamenusha.file_launcher

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class FileLauncherPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private val main = Handler(Looper.getMainLooper())
    private var worker = Executors.newSingleThreadExecutor()
    private var attached = false
    private var busy = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        if (worker.isShutdown) worker = Executors.newSingleThreadExecutor()
        attached = true
        channel = MethodChannel(binding.binaryMessenger, "file_launcher")
        channel.setMethodCallHandler(this)
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attached = false
        activity = null
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open", "share", "openBytes" -> prepare(call, result)
            "clearCache" -> clearCache(result)
            else -> result.notImplemented()
        }
    }

    private fun prepare(call: MethodCall, result: MethodChannel.Result) {
        if (busy) { result.success(response("busy", "Another file is being prepared")); return }
        val bytes: ByteArray?
        val source: File?
        val name: String
        if (call.method == "openBytes") {
            bytes = call.argument<ByteArray>("bytes")
            val fileName = call.argument<String>("fileName")
            if (bytes == null || fileName.isNullOrEmpty() || fileName == "." || fileName == ".." ||
                fileName.any { it == '/' || it == '\\' || it == '\u0000' }) {
                result.success(response("invalidPath", "Provide a file name without path separators")); return
            }
            source = null
            name = fileName
        } else {
            val path = call.argument<String>("path")
            if (path.isNullOrEmpty() || !File(path).isAbsolute || path.contains('\u0000')) {
                result.success(response("invalidPath", "Provide an absolute local file path")); return
            }
            bytes = null
            source = File(path)
            name = source.name
            if (!source.isFile) { result.success(response("fileNotFound", "No regular file at: $path")); return }
            if (!source.canRead()) { result.success(response("fileNotReadable", "File is not readable")); return }
        }
        val mime = try {
            FileTypeResolver.resolve(File(name), call.argument<String>("mimeType"))
        } catch (error: IllegalArgumentException) {
            result.success(response("error", error.message ?: "Invalid MIME type")); return
        }
        if (name.endsWith(".apk", ignoreCase = true) || mime.equals("application/vnd.android.package-archive", ignoreCase = true)) {
            result.success(response("error", "APK installation is not supported")); return
        }
        val mode = when {
            call.method == "share" -> LaunchMode.SHARE
            call.argument<Boolean>("showAppChooser") == true -> LaunchMode.CHOOSER
            else -> LaunchMode.VIEW
        }
        val title = call.argument<String>("title")?.takeIf { it.isNotBlank() } ?: name
        busy = true
        // Stage off the UI thread into the only directory exposed by FileProvider.
        worker.execute {
            var staged: File? = null
            try {
                val root = stagingRoot()
                root.mkdirs()
                // A file already inside the staging root is shared as-is, without a copy.
                val existing = source?.let { stagedEntry(root, it) }
                // Retain copies for seven days. Never remove them when a viewer closes:
                // recipients can continue to read asynchronously.
                val expiry = System.currentTimeMillis() - 7L * 24 * 60 * 60 * 1000
                root.listFiles()?.filter { it != existing && it.lastModified() < expiry }?.forEach { it.deleteRecursively() }
                val file = if (existing != null) source!!.canonicalFile else {
                    val directory = File(root, UUID.randomUUID().toString())
                    check(directory.mkdirs()) { "Could not create sharing cache" }
                    staged = directory
                    File(directory, name).also { copy ->
                        if (bytes != null) copy.writeBytes(bytes) else source!!.copyTo(copy)
                    }
                }
                main.post {
                    try {
                        result.success(if (attached) launch(file, mime, mode, title) else response("error", "Plugin detached before launch"))
                    } catch (error: Exception) {
                        result.success(response("error", error.message ?: "Could not launch file"))
                    } finally { busy = false }
                }
            } catch (error: Exception) {
                staged?.deleteRecursively()
                main.post {
                    busy = false
                    result.success(response("error", error.message ?: "Could not prepare file"))
                }
            }
        }
    }

    private fun clearCache(result: MethodChannel.Result) {
        if (busy) { result.success(false); return }
        busy = true
        worker.execute {
            val root = stagingRoot()
            val cleared = !root.exists() || root.deleteRecursively()
            main.post {
                busy = false
                result.success(cleared)
            }
        }
    }

    private fun launch(file: File, mime: String, mode: LaunchMode, title: String): Map<String, String> {
        val host = activity
        if (host == null || host.isFinishing || host.isDestroyed) {
            return response("error", "No foreground Activity; retry when the app is visible")
        }
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.file_launcher.provider", file)
        val status = FileLaunchIntents.open(uri, mime, file.name, mode, title) { host.startActivity(it) }
        val message = when (status) {
            "done" -> if (mode == LaunchMode.CHOOSER) "App chooser launch accepted for $mime" else "Viewer launch accepted for $mime"
            "shareSheet" -> "Share-sheet launch accepted for $mime"
            else -> "No activity can open or share this file"
        }
        return response(status, message)
    }

    private fun stagingRoot() = File(context.cacheDir, "file_launcher")

    private fun response(status: String, message: String) = mapOf("status" to status, "message" to message)

    internal companion object {
        /** The top-level entry of [root] that contains [file], or null if [file] is outside it. */
        fun stagedEntry(root: File, file: File): File? {
            val canonicalRoot = root.canonicalFile
            var current: File? = file.canonicalFile
            while (current != null) {
                val parent = current.parentFile
                if (parent == canonicalRoot) return current
                current = parent
            }
            return null
        }
    }
}
