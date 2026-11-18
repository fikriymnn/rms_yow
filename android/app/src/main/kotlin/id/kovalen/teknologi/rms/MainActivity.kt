package id.kovalen.teknologi.rms

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // ID perangkat yang TETAP walau aplikasi di-uninstall lalu dipasang lagi
        // (ANDROID_ID: unik per perangkat + kunci tanda tangan aplikasi, berubah hanya saat reset pabrik).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rms/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "androidId" -> result.success(
                        Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                    )
                    else -> result.notImplemented()
                }
            }
    }
}
