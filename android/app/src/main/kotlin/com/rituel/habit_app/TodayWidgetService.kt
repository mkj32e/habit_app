package com.rituel.habit_app

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class TodayWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = Factory(applicationContext)

    private class Factory(private val context: Context) : RemoteViewsFactory {
        private var items: List<WidgetHabit> = emptyList()

        override fun onCreate() = load()
        override fun onDataSetChanged() = load()
        override fun onDestroy() {}
        override fun getCount() = items.size
        override fun getLoadingView(): RemoteViews? = null
        override fun getViewTypeCount() = 1
        override fun getItemId(position: Int) = items.getOrNull(position)?.id?.hashCode()?.toLong() ?: position.toLong()
        override fun hasStableIds() = true

        private fun load() {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            items = WidgetData.habits(prefs)
        }

        override fun getViewAt(position: Int): RemoteViews {
            val v = RemoteViews(context.packageName, R.layout.widget_item)
            val h = items.getOrNull(position) ?: return v
            v.setTextViewText(R.id.item_emoji, h.emoji)
            v.setTextViewText(R.id.item_name, h.name)

            val parts = mutableListOf<String>()
            if (h.streak > 0) parts.add("🔥 ${h.streak} ${h.streakUnit}")
            if (h.target > 1) parts.add("${h.count}/${h.target} ${h.unit}".trim())
            if (!h.done && h.time.isNotEmpty()) parts.add("⏰ ${h.time}")
            if (parts.isEmpty()) parts.add(if (h.done) "Fait ✓" else "À faire")
            v.setTextViewText(R.id.item_sub, parts.joinToString("  ·  "))

            v.setTextColor(R.id.item_name, if (h.done) Color.argb(150, 255, 255, 255) else Color.WHITE)
            v.setImageViewResource(R.id.item_check, if (h.done) R.drawable.widget_check_on else R.drawable.widget_check_off)
            v.setInt(R.id.item_check, "setColorFilter", h.color)
            v.setInt(R.id.item_root, "setBackgroundResource", if (h.done) R.drawable.widget_item_bg_done else R.drawable.widget_item_bg)
            v.setTextViewText(R.id.item_plus, if (!h.done && h.target > 1) "+1" else "")
            v.setTextColor(R.id.item_plus, h.color)

            val fill = Intent().apply { data = Uri.parse("habitapp://toggle?id=${Uri.encode(h.id)}") }
            v.setOnClickFillInIntent(R.id.item_root, fill)
            return v
        }
    }
}
