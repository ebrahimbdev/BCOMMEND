package dev.bcommend.bcommend_mobile

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.system.Os
import android.system.OsConstants
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val diskExecutor = Executors.newSingleThreadExecutor()

    override fun onCreate(savedInstanceState: Bundle?) {
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.bcommend/storage")
            .setMethodCallHandler { call, result ->
                if (call.method != "syncDirectory") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("invalid_path", "An app-private directory is required", null)
                    return@setMethodCallHandler
                }
                diskExecutor.execute {
                    try {
                        val directory = File(path).canonicalFile
                        val root = File(applicationInfo.dataDir).canonicalFile
                        require(directory.isDirectory && directory.path.startsWith(root.path + File.separator))
                        val descriptor = Os.open(directory.path, OsConstants.O_RDONLY, 0)
                        try { Os.fsync(descriptor) } finally { Os.close(descriptor) }
                        Handler(Looper.getMainLooper()).post { result.success(null) }
                    } catch (_: Exception) {
                        Handler(Looper.getMainLooper()).post {
                            result.error("sync_failed", "Local storage durability could not be confirmed", null)
                        }
                    }
                }
            }
    }

    override fun onDestroy() {
        diskExecutor.shutdown()
        super.onDestroy()
    }
}
