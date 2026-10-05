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
        if (call.method != "open") { result.notImplemented(); return }
        if (busy) { result.success(response("error", "Another file is being prepared")); return }
        val path = call.argument<String>("path")
        if (path.isNullOrEmpty() || !File(path).isAbsolute || path.contains('\u0000')) {
            result.success(response("error", "Provide an absolute local file path")); return
        }
        val source = File(path)
        if (!source.isFile) { result.success(response("fileNotFound", "No regular file at: $path")); return }
        if (!source.canRead()) { result.success(response("error", "File is not readable")); return }
        val mime = try {
            FileTypeResolver.resolve(source, call.argument<String>("mimeType"))
        } catch (error: IllegalArgumentException) {
            result.success(response("error", error.message ?: "Invalid MIME type")); return
        }
        if (source.extension.equals("apk", ignoreCase = true) || mime.equals("application/vnd.android.package-archive", ignoreCase = true)) {
            result.success(response("error", "APK installation is not supported")); return
        }
        busy = true
        // Copy off the UI thread into the only directory exposed by FileProvider.
        worker.execute {
            var staged: File? = null
            try {
                val root = File(context.cacheDir, "file_launcher")
                root.mkdirs()
                // Retain copies for seven days. Never remove them when a viewer closes:
                // recipients can continue to read asynchronously.
                val expiry = System.currentTimeMillis() - 7L * 24 * 60 * 60 * 1000
                root.listFiles()?.filter { it.lastModified() < expiry }?.forEach { it.deleteRecursively() }
                val directory = File(root, UUID.randomUUID().toString())
                check(directory.mkdirs()) { "Could not create sharing cache" }
                val copy = File(directory, source.name)
                staged = copy
                source.copyTo(copy)
                main.post {
                    try {
                        result.success(if (attached) launch(copy, mime) else response("error", "Plugin detached before launch"))
                    } catch (error: Exception) {
                        result.success(response("error", error.message ?: "Could not launch file"))
                    } finally { busy = false }
                }
            } catch (error: Exception) {
                staged?.parentFile?.deleteRecursively()
                main.post {
                    busy = false
                    result.success(response("error", error.message ?: "Could not prepare file"))
                }
            }
        }
    }

    private fun launch(file: File, mime: String): Map<String, String> {
        val host = activity
        if (host == null || host.isFinishing || host.isDestroyed) {
            return response("error", "No foreground Activity; retry when the app is visible")
        }
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.file_launcher.provider", file)
        val status = FileLaunchIntents.open(uri, mime, file.name) { host.startActivity(it) }
        val message = when (status) {
            "done" -> "Viewer launch accepted for $mime"
            "shareSheet" -> "Share-sheet launch accepted for $mime"
            else -> "No activity can open or share this file"
        }
        return response(status, message)
    }

    private fun response(status: String, message: String) = mapOf("status" to status, "message" to message)
}
