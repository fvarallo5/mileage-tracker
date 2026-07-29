package com.mileagetracker.mileage_tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget: live trip status + today miles + start/stop deep links.
 */
class TrekTrackWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, R.layout.trektrack_widget).apply {
            val tracking = widgetData.getBoolean("tracking", false)
            val status = widgetData.getString("status", null) ?: "Ready"
            val tripLabel =
                widgetData.getString("trip_label", null) ?: "Tap to open TrekTrack"
            val todayLabel =
                widgetData.getString("today_label", null) ?: "0.0 mi today"
            val actionLabel =
                widgetData.getString("action_label", null)
                    ?: if (tracking) "Stop trip" else "Start trip"

            setTextViewText(R.id.widget_status, status)
            setTextViewText(R.id.widget_trip, tripLabel)
            setTextViewText(R.id.widget_today, todayLabel)
            setTextViewText(R.id.widget_action, actionLabel)

            // Open app
            val openApp =
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            setOnClickPendingIntent(R.id.widget_root, openApp)

            // Start / stop via existing deep links handled in MainActivity
            val actionUri =
                if (tracking) {
                  Uri.parse("mileagetracker://stop-trip")
                } else {
                  Uri.parse("mileagetracker://start-trip")
                }
            val actionIntent =
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    actionUri,
                )
            setOnClickPendingIntent(R.id.widget_action, actionIntent)

            // Visual cue while tracking
            setViewVisibility(
                R.id.widget_dot,
                if (tracking) View.VISIBLE else View.INVISIBLE,
            )
          }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
