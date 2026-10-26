package dev.rishithamenusha.file_launcher

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [28])
class FileLauncherPluginTest {
    @Test fun unknownMethod() {
        val result = Mockito.mock(MethodChannel.Result::class.java)
        FileLauncherPlugin().onMethodCall(MethodCall("unknown", null), result)
        Mockito.verify(result).notImplemented()
    }
    @Test fun invalidPath() {
        val result = Mockito.mock(MethodChannel.Result::class.java)
        FileLauncherPlugin().onMethodCall(MethodCall("open", mapOf("path" to "relative")), result)
        Mockito.verify(result).success(mapOf("status" to "invalidPath", "message" to "Provide an absolute local file path"))
    }
    @Test fun bytesNeedASingleSegmentFileName() {
        for (name in listOf("", ".", "..", "dir/file.pdf", "dir\\file.pdf", "a\u0000b")) {
            val result = Mockito.mock(MethodChannel.Result::class.java)
            FileLauncherPlugin().onMethodCall(MethodCall("openBytes", mapOf("bytes" to ByteArray(1), "fileName" to name)), result)
            Mockito.verify(result).success(mapOf("status" to "invalidPath", "message" to "Provide a file name without path separators"))
        }
    }
    @Test fun apkBytesAreRejected() {
        val result = Mockito.mock(MethodChannel.Result::class.java)
        FileLauncherPlugin().onMethodCall(MethodCall("openBytes", mapOf("bytes" to ByteArray(1), "fileName" to "app.APK")), result)
        Mockito.verify(result).success(mapOf("status" to "error", "message" to "APK installation is not supported"))
    }
    @Test fun sharingMissingFileReportsNotFound() {
        val result = Mockito.mock(MethodChannel.Result::class.java)
        FileLauncherPlugin().onMethodCall(MethodCall("share", mapOf("path" to "/absent/file.pdf")), result)
        Mockito.verify(result).success(mapOf("status" to "fileNotFound", "message" to "No regular file at: /absent/file.pdf"))
    }
    @Test fun stagedFilesAreRecognizedWithoutCopying() {
        val root = java.nio.file.Files.createTempDirectory("staging").toFile()
        try {
            val nested = File(root, "id/report.pdf").apply { parentFile!!.mkdirs(); writeText("x") }
            assertEquals(File(root, "id").canonicalFile, FileLauncherPlugin.stagedEntry(root, nested))
            assertEquals(File(root, "id").canonicalFile, FileLauncherPlugin.stagedEntry(root, File(root, "id/../id/report.pdf")))
            assertNull(FileLauncherPlugin.stagedEntry(root, File(root.parentFile, "elsewhere.pdf")))
            assertNull(FileLauncherPlugin.stagedEntry(root, root))
        } finally { root.deleteRecursively() }
    }
    @Test fun directoryIsNotAFile() {
        val path = System.getProperty("java.io.tmpdir")!!
        val result = Mockito.mock(MethodChannel.Result::class.java)
        FileLauncherPlugin().onMethodCall(MethodCall("open", mapOf("path" to path)), result)
        Mockito.verify(result).success(mapOf("status" to "fileNotFound", "message" to "No regular file at: $path"))
    }
    @Test fun apkIsRejectedWithoutLaunchingInstaller() {
        val file = File.createTempFile("sample", ".apk")
        try {
            val result = Mockito.mock(MethodChannel.Result::class.java)
            FileLauncherPlugin().onMethodCall(MethodCall("open", mapOf("path" to file.path)), result)
            Mockito.verify(result).success(mapOf("status" to "error", "message" to "APK installation is not supported"))
        } finally { file.delete() }
    }
}
