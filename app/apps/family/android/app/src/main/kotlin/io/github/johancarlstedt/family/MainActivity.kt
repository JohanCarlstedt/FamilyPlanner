package io.github.johancarlstedt.family

import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val phoneCalendars = PhoneCalendarReader(this)

    /** Opened from the app icon's "Add to shopping list", not yet heard. */
    private var listenPending = false
    private var voice: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        listenPending = wantsListening(intent)
        publishShortcuts()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Already running: tell it now rather than on the next start.
        if (wantsListening(intent)) voice?.invokeMethod("listen", null)
    }

    private fun wantsListening(intent: Intent?) = intent?.action == ACTION_ADD_SHOPPING

    /**
     * Long-press the app icon: "Add to shopping list", which opens the
     * app listening. Registered from here rather than res/xml/shortcuts.xml,
     * which has to name the app's package outright and so could only ever
     * be right for one of dev and prod.
     */
    private fun publishShortcuts() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return
        val shortcuts = getSystemService(ShortcutManager::class.java) ?: return
        val addShopping = ShortcutInfo.Builder(this, "add_shopping")
            .setShortLabel(getString(R.string.shortcut_add_shopping_short))
            .setLongLabel(getString(R.string.shortcut_add_shopping_long))
            .setIcon(Icon.createWithResource(this, R.drawable.ic_shortcut_shopping))
            .setIntent(Intent(this, MainActivity::class.java).setAction(ACTION_ADD_SHOPPING))
            .build()
        shortcuts.dynamicShortcuts = listOf(addShopping)
    }

    /**
     * Whether the family map has a key to draw with. It comes from
     * android/maps.properties, which is gitignored, so a checkout without
     * one shows the map's list and says why rather than drawing nothing.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PhoneCalendarReader.CHANNEL)
            .setMethodCallHandler(phoneCalendars)
        voice = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "family/voice").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "take" -> result.success(VoiceQueue.take(this@MainActivity))
                    "listenRequested" -> {
                        result.success(listenPending)
                        listenPending = false
                    }
                    else -> result.notImplemented()
                }
            }
        }
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

    companion object {
        const val ACTION_ADD_SHOPPING = "io.github.johancarlstedt.family.ADD_SHOPPING"
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        phoneCalendars.answered(requestCode, grantResults)
    }
}
