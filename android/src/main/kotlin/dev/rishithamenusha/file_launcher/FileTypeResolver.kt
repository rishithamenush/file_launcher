package dev.rishithamenusha.file_launcher

import android.webkit.MimeTypeMap
import java.io.File
import java.util.Locale

/** Stable common types across Android releases; system lookup for other formats. */
internal object FileTypeResolver {
    fun resolve(file: File, override: String?): String {
        val explicit = override?.trim()?.lowercase(Locale.ROOT)
        if (!explicit.isNullOrEmpty()) {
            require(MIME.matches(explicit)) { "mimeType must be a type/subtype such as application/pdf" }
            return explicit
        }
        val extension = file.extension.lowercase(Locale.ROOT)
        return TYPES[extension] ?: MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension) ?: "*/*"
    }

    private val MIME = Regex("(?:[a-z0-9!#$&^_.+\\-]+|\\*)/(?:[a-z0-9!#$&^_.+\\-]+|\\*)")
    private val TYPES = mapOf(
        "pdf" to "application/pdf",
        "mp3" to "audio/mpeg", "m4a" to "audio/mp4", "m4b" to "audio/mp4",
        "aac" to "audio/aac", "wav" to "audio/wav", "flac" to "audio/flac",
        "ogg" to "audio/ogg", "oga" to "audio/ogg", "opus" to "audio/ogg",
        "aif" to "audio/x-aiff", "aiff" to "audio/x-aiff", "amr" to "audio/amr",
        "mid" to "audio/midi", "midi" to "audio/midi",
        "mp4" to "video/mp4", "m4v" to "video/mp4", "mov" to "video/quicktime",
        "webm" to "video/webm", "mkv" to "video/x-matroska", "avi" to "video/x-msvideo",
        "3gp" to "video/3gpp", "mpeg" to "video/mpeg", "mpg" to "video/mpeg",
        "jpg" to "image/jpeg", "jpeg" to "image/jpeg", "png" to "image/png",
        "gif" to "image/gif", "webp" to "image/webp", "heic" to "image/heic",
        "heif" to "image/heif", "bmp" to "image/bmp", "tif" to "image/tiff",
        "tiff" to "image/tiff", "svg" to "image/svg+xml", "avif" to "image/avif",
        "doc" to "application/msword",
        "docx" to "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "xls" to "application/vnd.ms-excel",
        "xlsx" to "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "ppt" to "application/vnd.ms-powerpoint",
        "pptx" to "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        "odt" to "application/vnd.oasis.opendocument.text",
        "ods" to "application/vnd.oasis.opendocument.spreadsheet",
        "odp" to "application/vnd.oasis.opendocument.presentation",
        "pages" to "application/vnd.apple.pages", "numbers" to "application/vnd.apple.numbers",
        "key" to "application/vnd.apple.keynote",
        "txt" to "text/plain", "csv" to "text/csv", "md" to "text/markdown",
        "json" to "application/json", "xml" to "application/xml", "rtf" to "application/rtf",
        "html" to "text/html", "htm" to "text/html", "log" to "text/plain",
        "zip" to "application/zip", "7z" to "application/x-7z-compressed",
        "rar" to "application/vnd.rar", "tar" to "application/x-tar", "gz" to "application/gzip",
        "epub" to "application/epub+zip", "vcf" to "text/vcard", "ics" to "text/calendar",
        "usdz" to "model/vnd.usdz+zip", "apk" to "application/vnd.android.package-archive",
    )
}
