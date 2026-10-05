package dev.rishithamenusha.file_launcher

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.util.Locale

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [28])
class FileRoutingTest {
    private val uri = Uri.parse("content://example.file_launcher.provider/shared_files/id/sample")

    @Test fun pdfAndAudioHaveSpecificViewerTypes() {
        val types = mapOf("pdf" to "application/pdf", "mp3" to "audio/mpeg",
            "m4a" to "audio/mp4", "aac" to "audio/aac", "wav" to "audio/wav",
            "flac" to "audio/flac", "ogg" to "audio/ogg", "opus" to "audio/ogg",
            "mp4" to "video/mp4", "mov" to "video/quicktime")
        for ((ext, mime) in types) assertEquals(mime, FileTypeResolver.resolve(File("/sample.$ext"), null))
    }
    @Test fun officeAndImagesRouteToTheirOwnViewers() {
        assertEquals("image/jpeg", FileTypeResolver.resolve(File("/My picture.JPEG"), null))
        assertEquals("application/vnd.openxmlformats-officedocument.wordprocessingml.document", FileTypeResolver.resolve(File("/report.docx"), null))
        assertEquals("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", FileTypeResolver.resolve(File("/report.xlsx"), null))
        assertEquals("application/vnd.openxmlformats-officedocument.presentationml.presentation", FileTypeResolver.resolve(File("/report.pptx"), null))
    }
    @Test fun extensionHandlingIsIndependentOfDeviceLocale() {
        val previous = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("tr-TR"))
            assertEquals("image/tiff", FileTypeResolver.resolve(File("/IMAGE.TIFF"), null))
        } finally { Locale.setDefault(previous) }
    }
    @Test fun overrideWorksForExtensionlessFilesAndIsNormalized() {
        assertEquals("application/pdf", FileTypeResolver.resolve(File("/download"), " Application/PDF "))
        assertEquals("audio/mpeg", FileTypeResolver.resolve(File("/download.bin"), "audio/mpeg"))
        assertEquals("audio/mpeg", FileTypeResolver.resolve(File("/sample.mp3"), "  "))
    }
    @Test fun unknownFilesUseGenericType() {
        assertEquals("*/*", FileTypeResolver.resolve(File("/sample.unrecognizableformat"), null))
        assertEquals("*/*", FileTypeResolver.resolve(File("/download"), null))
    }
    @Test fun invalidOverrideIsRejected() {
        assertThrows(IllegalArgumentException::class.java) { FileTypeResolver.resolve(File("/file.pdf"), "pdf") }
    }
    @Test fun pdfAndAudioLaunchWithReadOnlyUriGrants() {
        for (mime in listOf("application/pdf", "audio/mpeg", "audio/mp4", "audio/wav")) {
            val calls = mutableListOf<Intent>()
            assertEquals("done", FileLaunchIntents.open(uri, mime, "sample") { calls.add(it) })
            assertEquals(1, calls.size)
            val view = calls.single()
            assertEquals(Intent.ACTION_VIEW, view.action)
            assertEquals(mime, view.type)
            assertEquals(uri, view.data)
            assertEquals(uri, view.clipData!!.getItemAt(0).uri)
            assertEquals(Intent.FLAG_GRANT_READ_URI_PERMISSION, view.flags)
        }
    }
    @Test fun noViewerFallsBackToShareWithSameFileAndType() {
        val calls = mutableListOf<Intent>()
        val result = FileLaunchIntents.open(uri, "audio/flac", "sample.flac") {
            calls.add(it)
            if (it.action == Intent.ACTION_VIEW) throw ActivityNotFoundException()
        }
        assertEquals("shareSheet", result)
        assertEquals(2, calls.size)
        val chooser = calls.last()
        assertEquals(Intent.ACTION_CHOOSER, chooser.action)
        @Suppress("DEPRECATION")
        val send = chooser.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)!!
        assertEquals(Intent.ACTION_SEND, send.action)
        assertEquals("audio/flac", send.type)
        @Suppress("DEPRECATION")
        assertEquals(uri, send.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
        assertEquals(uri, chooser.clipData!!.getItemAt(0).uri)
        assertEquals(uri, send.clipData!!.getItemAt(0).uri)
        assertEquals(Intent.FLAG_GRANT_READ_URI_PERMISSION, send.flags)
    }
    @Test fun absentViewerAndChooserReturnsNoApp() {
        assertEquals("noAppToOpen", FileLaunchIntents.open(uri, "application/pdf", "a.pdf") { throw ActivityNotFoundException() })
    }
    @Test fun permissionFailuresAreNotReportedAsSuccessfulLaunches() {
        assertThrows(SecurityException::class.java) {
            FileLaunchIntents.open(uri, "application/pdf", "a.pdf") { throw SecurityException("denied") }
        }
    }
}
