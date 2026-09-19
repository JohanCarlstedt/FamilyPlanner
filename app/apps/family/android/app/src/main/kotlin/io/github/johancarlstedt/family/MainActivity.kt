package io.github.johancarlstedt.family

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /**
     * Whether the family map has a key to draw with. It comes from
     * android/maps.properties, which is gitignored, so a checkout without
     * one shows the map's list and says why rather than drawing nothing.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "family/maps")
            .setMethodCallHandler { call, result ->
                if (call.method == "hasKey") {
                    val info = packageManager.getApplicationInfo(
                        packageName,
                        PackageManager.GET_META_DATA,
                    )
                    val key = info.metaData
                        ?.getString("com.google.android.geo.API_KEY")
                        .orEmpty()
                    result.success(key.isNotBlank())
                } else {
                    result.notImplemented()
                }
            }
    }
}
