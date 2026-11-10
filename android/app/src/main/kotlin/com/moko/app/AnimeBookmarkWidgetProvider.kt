package com.moko.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class AnimeBookmarkWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_anime_bookmark)

            // Setup collection adapter
            val serviceIntent = Intent(context, AnimeBookmarkWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_list, serviceIntent)
            views.setEmptyView(R.id.widget_list, R.id.widget_empty_view)

            // Setup PendingIntent template for items
            val templateIntent = Intent(context, MainActivity::class.java).apply {
                action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= 31) {
                flags = flags or PendingIntent.FLAG_MUTABLE
            }
            val pendingIntent = PendingIntent.getActivity(context, 102, templateIntent, flags)
            views.setPendingIntentTemplate(R.id.widget_list, pendingIntent)

            // Header click opens MOKO app
            val appIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("moko://continue_list")
            )
            views.setOnClickPendingIntent(R.id.header_layout, appIntent)

            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
