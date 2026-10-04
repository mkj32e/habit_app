package com.rituel.habit_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Compact widget: daily ring, best running streak and level. */
class ProgressWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val done = if (WidgetData.isStale(widgetData)) 0 else WidgetData.int(widgetData, "today_done")
        val total = WidgetData.int(widgetData, "today_total")
        val pct = if (total == 0) 0 else done * 100 / total
        val streak = WidgetData.int(widgetData, "top_streak")
        val perfect = WidgetData.int(widgetData, "perfect_streak")

        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.widget_progress)
            v.setProgressBar(R.id.ring, 100, pct, false)
            v.setTextViewText(R.id.ring_pct, "$pct%")
            v.setTextViewText(R.id.ring_count, "$done/$total")
            v.setTextViewText(R.id.streak, "🔥 $streak" + if (perfect > 0) "   ⭐ $perfect" else "")
            v.setTextViewText(R.id.level, WidgetData.string(widgetData, "level_label", "Niv. 1"))
            v.setProgressBar(R.id.level_bar, 100, WidgetData.int(widgetData, "level_progress"), false)
            v.setOnClickPendingIntent(R.id.progress_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
