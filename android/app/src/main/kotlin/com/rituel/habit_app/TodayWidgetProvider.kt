package com.rituel.habit_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** "Aujourd'hui" widget: progress header + list of today's habits, tap to check. */
class TodayWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val stale = WidgetData.isStale(widgetData)
        val done = if (stale) 0 else WidgetData.int(widgetData, "today_done")
        val total = WidgetData.int(widgetData, "today_total")
        val pct = if (total == 0) 0 else done * 100 / total
        val date = if (stale) WidgetData.todayLabel() else WidgetData.string(widgetData, "today_date", "Aujourd'hui")

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_today)
            views.setTextViewText(R.id.widget_date, date)
            views.setTextViewText(R.id.widget_count, "$done/$total")
            views.setTextViewText(
                R.id.widget_subtitle,
                when {
                    total == 0 -> "Rien de prévu aujourd'hui"
                    done == total -> "Journée parfaite ✨"
                    else -> "${total - done} restante${if (total - done > 1) "s" else ""} · $pct%"
                },
            )
            views.setProgressBar(R.id.widget_progress, 100, pct, false)

            // Header opens the app.
            val launch = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.widget_header, launch)
            views.setOnClickPendingIntent(R.id.widget_empty, launch)

            // List items.
            val svc = Intent(context, TodayWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_list, svc)
            views.setEmptyView(R.id.widget_list, R.id.widget_empty)

            // Item taps are routed to Dart in the background (no need to open the app).
            val toggle = Intent(context, HomeWidgetBackgroundReceiver::class.java).apply {
                action = "es.antonborri.home_widget.action.BACKGROUND"
            }
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) flags = flags or PendingIntent.FLAG_MUTABLE
            views.setPendingIntentTemplate(R.id.widget_list, PendingIntent.getBroadcast(context, 1, toggle, flags))

            views.setViewVisibility(R.id.widget_all_done, if (total > 0 && done == total) View.VISIBLE else View.GONE)

            appWidgetManager.updateAppWidget(id, views)
        }
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_list)
    }
}
