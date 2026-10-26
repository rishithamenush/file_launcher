package dev.rishithamenusha.file_launcher

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.net.Uri

/** How to hand a file to other apps. */
internal enum class LaunchMode {
    /** The default viewer, then the share chooser. */
    VIEW,
    /** Always ask which viewer to use ("Open with"), then the share chooser. */
    CHOOSER,
    /** The share chooser only. */
    SHARE,
}

/** Builds every route with the same type and read-only access to one file. */
internal object FileLaunchIntents {
    fun open(
        uri: Uri,
        mime: String,
        name: String,
        mode: LaunchMode = LaunchMode.VIEW,
        title: String = name,
        start: (Intent) -> Unit,
    ): String {
        val clip = ClipData.newRawUri(name, uri)
        if (mode != LaunchMode.SHARE) {
            val view = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                clipData = clip
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val launch = if (mode == LaunchMode.CHOOSER) chooser(view, title, clip) else view
            if (tryStart(launch, start)) return "done"
        }
        val send = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = clip
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        if (tryStart(chooser(send, title, clip), start)) return "shareSheet"
        return "noAppToOpen"
    }

    private fun chooser(target: Intent, title: String, clip: ClipData) =
        Intent.createChooser(target, title).apply {
            clipData = clip
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

    private fun tryStart(intent: Intent, start: (Intent) -> Unit): Boolean = try {
        start(intent)
        true
    } catch (_: ActivityNotFoundException) { false }
}
