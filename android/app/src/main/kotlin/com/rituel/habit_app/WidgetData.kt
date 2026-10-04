package com.rituel.habit_app

import android.content.SharedPreferences
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

data class WidgetHabit(
    val id: String,
    val name: String,
    val emoji: String,
    val color: Int,
    val done: Boolean,
    val count: Int,
    val target: Int,
    val unit: String,
    val streak: Int,
    val streakUnit: String,
    val time: String,
)

/** Reads the state pushed by the Flutter side (WidgetService.update). */
object WidgetData {
    /** True when the data was written on a previous day (app not opened since midnight). */
    fun isStale(prefs: SharedPreferences): Boolean {
        val key = prefs.getString("today_key", null) ?: return false
        return key != SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    }

    fun todayLabel(): String =
        SimpleDateFormat("EEEE d MMMM", Locale.FRENCH).format(Date()).replaceFirstChar { it.uppercase() }

    fun habits(prefs: SharedPreferences): List<WidgetHabit> {
        val stale = isStale(prefs)
        val raw = prefs.getString("today_items", null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                WidgetHabit(
                    id = o.optString("id"),
                    name = o.optString("name"),
                    emoji = o.optString("emoji", "✨"),
                    color = o.optLong("color", 0xFF7C5CFF).toInt(),
                    done = !stale && o.optBoolean("done"),
                    count = if (stale) 0 else o.optInt("count"),
                    target = o.optInt("target", 1),
                    unit = o.optString("unit"),
                    streak = o.optInt("streak"),
                    streakUnit = o.optString("streakUnit", "j"),
                    time = o.optString("time"),
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun int(prefs: SharedPreferences, key: String, def: Int = 0): Int =
        (prefs.all[key] as? Number)?.toInt() ?: def

    fun string(prefs: SharedPreferences, key: String, def: String = ""): String =
        prefs.getString(key, def) ?: def
}
