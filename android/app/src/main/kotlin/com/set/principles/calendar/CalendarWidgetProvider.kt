package com.set.principles.calendar

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews
import com.set.principles.R
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

abstract class CalendarWidgetProvider : HomeWidgetProvider() {
    abstract val kind: CalendarWidgetKind

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_SHIFT) {
            val widgetId =
                intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                val snapshot = currentSnapshot(context)
                val delta = intent.getIntExtra(EXTRA_DELTA, 0)
                if (intent.getStringExtra(EXTRA_UNIT) == UNIT_WEEK) {
                    CalendarWidgetState.shiftWeek(context, widgetId, snapshot.today, delta)
                } else {
                    CalendarWidgetState.shiftMonth(context, widgetId, snapshot.today, delta)
                }
                publish(context, AppWidgetManager.getInstance(context), widgetId, snapshot)
            }
        }
        super.onReceive(context, intent)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val snapshot = parseSnapshot(widgetData)
        for (widgetId in appWidgetIds) {
            publish(context, appWidgetManager, widgetId, snapshot)
        }
    }

    private fun publish(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        snapshot: CalendarSnapshot,
    ) {
        try {
            appWidgetManager.updateAppWidget(
                widgetId,
                CalendarWidgetViews.build(context, widgetId, kind, snapshot),
            )
        } catch (e: Exception) {
            // Binder / RemoteViews size failures leave the empty initialLayout;
            // fall back to a compact static shell so the home screen is not blank.
            Log.e(TAG, "Calendar widget update failed for $widgetId", e)
            try {
                appWidgetManager.updateAppWidget(widgetId, fallbackViews(context))
            } catch (fallbackError: Exception) {
                Log.e(TAG, "Calendar widget fallback failed for $widgetId", fallbackError)
            }
        }
    }

    private fun fallbackViews(context: Context): RemoteViews {
        // Prefer the empty runtime shell over static previews — previews are for the
        // picker only and must stay free of unsupported RemoteViews tags / includes.
        val layout =
            when (kind) {
                CalendarWidgetKind.TODAY -> R.layout.calendar_widget_today
                CalendarWidgetKind.WEEK -> R.layout.calendar_widget_week
                CalendarWidgetKind.MONTH -> R.layout.calendar_widget_month
            }
        return RemoteViews(context.packageName, layout)
    }

    private fun currentSnapshot(context: Context): CalendarSnapshot =
        parseSnapshot(HomeWidgetPlugin.getData(context))

    private fun parseSnapshot(widgetData: SharedPreferences): CalendarSnapshot =
        CalendarSnapshotParser.parse(widgetData.getString(SNAPSHOT_KEY, null))

    companion object {
        private const val TAG = "CalendarWidget"
        const val ACTION_SHIFT = "com.set.principles.calendar.SHIFT"
        const val EXTRA_DELTA = "delta"
        const val EXTRA_UNIT = "unit"
        const val UNIT_MONTH = "month"
        const val UNIT_WEEK = "week"
        const val SNAPSHOT_KEY = "calendar_snapshot"
    }
}

class CalendarMonthWidgetProvider : CalendarWidgetProvider() {
    override val kind = CalendarWidgetKind.MONTH
}

class CalendarWeekWidgetProvider : CalendarWidgetProvider() {
    override val kind = CalendarWidgetKind.WEEK
}

class CalendarTodayWidgetProvider : CalendarWidgetProvider() {
    override val kind = CalendarWidgetKind.TODAY
}
