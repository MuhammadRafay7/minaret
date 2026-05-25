package com.atelier.minaret

// PrayerWidgetProvider temporarily disabled due to home_widget compatibility issues
// Original implementation required es.antonborri.home_widget.HomeWidgetProvider

/*
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PrayerWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.prayer_widget).apply {
                setTextViewText(R.id.widget_prayer_name, widgetData.getString("next_prayer_name", "---"))
                setTextViewText(R.id.widget_prayer_time, widgetData.getString("next_prayer_time", "--:--"))
                setTextViewText(R.id.widget_hijri, widgetData.getString("hijri_date", "---"))
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
*/
