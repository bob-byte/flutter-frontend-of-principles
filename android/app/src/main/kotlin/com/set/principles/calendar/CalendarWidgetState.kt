package com.set.principles.calendar

import android.content.Context
import java.time.LocalDate

object CalendarWidgetState {
    private const val PREFS = "calendar_widget_state"

    fun visibleMonth(context: Context, widgetId: Int, today: LocalDate): LocalDate {
        val raw = prefs(context).getString(monthKey(widgetId), null)
        return CalendarSnapshotParser.parseDate(raw)?.withDayOfMonth(1)
            ?: today.withDayOfMonth(1)
    }

    fun visibleWeekAnchor(context: Context, widgetId: Int, today: LocalDate): LocalDate {
        val raw = prefs(context).getString(weekKey(widgetId), null)
        return CalendarSnapshotParser.parseDate(raw) ?: today
    }

    fun shiftMonth(context: Context, widgetId: Int, today: LocalDate, delta: Int) {
        val next =
            if (delta == 0) {
                today.withDayOfMonth(1)
            } else {
                visibleMonth(context, widgetId, today).plusMonths(delta.toLong())
            }
        prefs(context).edit().putString(monthKey(widgetId), next.toString()).apply()
    }

    fun shiftWeek(context: Context, widgetId: Int, today: LocalDate, delta: Int) {
        val next =
            if (delta == 0) {
                today
            } else {
                visibleWeekAnchor(context, widgetId, today).plusWeeks(delta.toLong())
            }
        prefs(context).edit().putString(weekKey(widgetId), next.toString()).apply()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun monthKey(widgetId: Int) = "visible_month_$widgetId"

    private fun weekKey(widgetId: Int) = "visible_week_$widgetId"
}
