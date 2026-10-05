package dev.rishithamenusha.file_launcher

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.net.Uri

/** Builds both routes with the same type and read-only access to one file. */
internal object FileLaunchIntents {
    fun open(uri: Uri, mime: String, name: String, start: (Intent) -> Unit): String {
        val clip = ClipData.newRawUri(name, uri)
        val view = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mime)
            clipData = clip
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        if (tryStart(view, start)) return "done"
        val send = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = clip
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val chooser = Intent.createChooser(send, name).apply {
            clipData = clip
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        if (tryStart(chooser, start)) return "shareSheet"
        return "noAppToOpen"
    }

    private fun tryStart(intent: Intent, start: (Intent) -> Unit): Boolean = try {
        start(intent)
        true
    } catch (_: ActivityNotFoundException) { false }
}
