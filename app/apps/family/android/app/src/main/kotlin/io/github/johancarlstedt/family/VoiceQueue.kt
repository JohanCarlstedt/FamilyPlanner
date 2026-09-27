package io.github.johancarlstedt.family

import android.content.Context
import org.json.JSONArray

/**
 * What was said to the phone for the family while the app's own screens
 * could not take it: items for the shopping list, activities to log. The
 * same queue the iPhone keeps for Siri (ios/Runner/AppDelegate.swift,
 * VoiceQueue): whatever writes here, lib/src/common/voice_inbox.dart
 * takes it when the app starts or comes back, and adds it through the
 * encrypted store. Nothing here is sent anywhere.
 */
object VoiceQueue {
    const val SHOPPING = "voice.shopping"
    const val ACTIVITY = "voice.activity"
    private const val PREFS = "family_voice"

    @Synchronized
    fun add(context: Context, key: String, items: List<String>) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val queued = JSONArray(prefs.getString(key, "[]"))
        for (item in items) {
            if (item.isNotBlank()) queued.put(item.trim())
        }
        prefs.edit().putString(key, queued.toString()).apply()
    }

    /** Everything queued, which is then cleared: taken once. */
    @Synchronized
    fun take(context: Context): Map<String, List<String>> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val out = mutableMapOf<String, List<String>>()
        val editor = prefs.edit()
        for (key in listOf(SHOPPING, ACTIVITY)) {
            val queued = JSONArray(prefs.getString(key, "[]"))
            out[key] = List(queued.length()) { queued.getString(it) }
            editor.remove(key)
        }
        editor.apply()
        return out
    }
}
