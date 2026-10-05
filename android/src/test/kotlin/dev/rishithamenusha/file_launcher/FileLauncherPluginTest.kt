package dev.rishithamenusha.file_launcher

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
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
        Mockito.verify(result).success(mapOf("status" to "error", "message" to "Provide an absolute local file path"))
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
