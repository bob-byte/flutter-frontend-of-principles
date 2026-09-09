package com.set.principles.calendar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import com.set.principles.MainActivity
import com.set.principles.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale

enum class CalendarWidgetKind { MONTH, WEEK, TODAY }

object CalendarWidgetViews {
    fun build(
        context: Context,
        widgetId: Int,
        kind: CalendarWidgetKind,
        snapshot: CalendarSnapshot,
    ): RemoteViews {
        return when (kind) {
            CalendarWidgetKind.TODAY -> buildToday(context, snapshot)
            CalendarWidgetKind.WEEK -> buildCalendar(context, widgetId, snapshot, week = true)
            CalendarWidgetKind.MONTH -> buildCalendar(context, widgetId, snapshot, week = false)
        }
    }

    private fun buildToday(context: Context, snapshot: CalendarSnapshot): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.calendar_widget_today)
        val theme = snapshot.theme
        views.setInt(R.id.calendar_root, "setBackgroundColor", theme.background)
        views.setTextColor(R.id.today_weekday, theme.textMuted)
        views.setTextColor(R.id.today_number, theme.text)
        views.setTextColor(R.id.btn_add, theme.primary)
        views.setTextViewText(R.id.btn_add, "+")
        views.setTextViewText(
            R.id.today_weekday,
            snapshot.today.dayOfWeek
                .getDisplayName(TextStyle.SHORT, localeFor(snapshot.locale))
                .uppercase(localeFor(snapshot.locale)),
        )
        views.setTextViewText(R.id.today_number, snapshot.today.dayOfMonth.toString())
        views.setOnClickPendingIntent(
            R.id.btn_add,
            launch(context, action = "create", date = snapshot.today),
        )
        views.setOnClickPendingIntent(
            R.id.calendar_root,
            launch(context, action = "today"),
        )

        views.removeAllViews(R.id.events)
        val upcoming = snapshot.upcoming()
        if (upcoming.isEmpty()) {
            views.setViewVisibility(R.id.empty, View.VISIBLE)
            views.setTextColor(R.id.empty, theme.textMuted)
            views.setTextViewText(R.id.empty, snapshot.labels.empty)
        } else {
            views.setViewVisibility(R.id.empty, View.GONE)
            for (item in upcoming) {
                views.addView(R.id.events, eventRow(context, item, theme))
            }
        }
        return views
    }

    private fun buildCalendar(
        context: Context,
        widgetId: Int,
        snapshot: CalendarSnapshot,
        week: Boolean,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.calendar_widget_month)
        val theme = snapshot.theme
        views.setInt(R.id.calendar_root, "setBackgroundColor", theme.background)
        views.setTextColor(R.id.month_title, theme.text)
        views.setTextColor(R.id.btn_prev, theme.text)
        views.setTextColor(R.id.btn_next, theme.text)
        views.setTextColor(R.id.btn_add, theme.primary)
        views.setTextViewText(R.id.btn_add, "+")
        views.setTextViewText(R.id.btn_today, snapshot.today.dayOfMonth.toString())
        views.setTextColor(R.id.btn_today, theme.todayText)
        views.setInt(R.id.btn_today, "setBackgroundColor", theme.todayFill)

        val unit = if (week) CalendarWidgetProvider.UNIT_WEEK else CalendarWidgetProvider.UNIT_MONTH
        val anchor =
            if (week) {
                CalendarWidgetState.visibleWeekAnchor(context, widgetId, snapshot.today)
            } else {
                CalendarWidgetState.visibleMonth(context, widgetId, snapshot.today)
            }
        val title =
            if (week) {
                val days = weekDays(anchor, snapshot.weekStartsOn)
                val month = snapshot.labels.monthNamesShort.getOrElse(days.first().monthValue - 1) {
                    days.first().month.name
                }
                "${month.uppercase(localeFor(snapshot.locale))} ${days.first().dayOfMonth}–${days.last().dayOfMonth}"
            } else {
                val name = snapshot.labels.monthNames.getOrElse(anchor.monthValue - 1) {
                    anchor.month.name
                }
                val shown = name.uppercase(localeFor(snapshot.locale))
                if (anchor.year == snapshot.today.year) shown else "$shown ${anchor.year}"
            }
        views.setTextViewText(R.id.month_title, title)

        views.setOnClickPendingIntent(R.id.btn_prev, shiftIntent(context, widgetId, unit, -1))
        views.setOnClickPendingIntent(R.id.btn_next, shiftIntent(context, widgetId, unit, 1))
        views.setOnClickPendingIntent(R.id.btn_today, shiftIntent(context, widgetId, unit, 0))
        views.setOnClickPendingIntent(
            R.id.btn_add,
            launch(context, action = "create", date = snapshot.today),
        )

        views.removeAllViews(R.id.weekday_row)
        for (index in 0 until 7) {
            val label = RemoteViews(context.packageName, R.layout.calendar_widget_weekday)
            val text = snapshot.labels.weekdays.getOrElse(index) { "" }
            val sunday = index == 6
            label.setTextViewText(R.id.weekday_label, text)
            label.setTextColor(R.id.weekday_label, if (sunday) theme.sunday else theme.textMuted)
            views.addView(R.id.weekday_row, label)
        }

        views.removeAllViews(R.id.grid)
        val days = if (week) weekDays(anchor, snapshot.weekStartsOn) else monthGrid(anchor, snapshot.weekStartsOn)
        val rows = if (week) 1 else 6
        val maxEvents = if (week) 4 else 2
        for (row in 0 until rows) {
            val rowViews = RemoteViews(context.packageName, R.layout.calendar_widget_week_row)
            for (col in 0 until 7) {
                val day = days[row * 7 + col]
                rowViews.addView(
                    R.id.week_row,
                    dayCell(context, snapshot, day, week, maxEvents, inMonth = day.month == anchor.month),
                )
            }
            views.addView(R.id.grid, rowViews)
        }
        return views
    }

    private fun dayCell(
        context: Context,
        snapshot: CalendarSnapshot,
        day: LocalDate,
        week: Boolean,
        maxEvents: Int,
        inMonth: Boolean,
    ): RemoteViews {
        val theme = snapshot.theme
        val views = RemoteViews(
            context.packageName,
            if (week) R.layout.calendar_widget_day_cell_week else R.layout.calendar_widget_day_cell,
        )
        val isToday = day == snapshot.today
        val numberColor =
            when {
                isToday -> theme.todayText
                !inMonth -> theme.textMuted
                day.dayOfWeek.value == 7 -> theme.sunday
                else -> theme.text
            }
        views.setTextViewText(R.id.day_number, day.dayOfMonth.toString())
        views.setTextColor(R.id.day_number, numberColor)
        if (isToday) {
            views.setInt(R.id.day_number, "setBackgroundColor", theme.todayFill)
        } else {
            views.setInt(R.id.day_number, "setBackgroundColor", 0x00000000)
        }
        views.setOnClickPendingIntent(
            R.id.day_root,
            launch(context, action = "day", date = day),
        )

        val items = snapshot.itemsOn(day)
        bindEvent(views, R.id.event1, R.id.event1_bar, R.id.event1_text, items.getOrNull(0), theme)
        bindEvent(views, R.id.event2, R.id.event2_bar, R.id.event2_text, items.getOrNull(1), theme)
        if (week) {
            bindEvent(views, R.id.event3, R.id.event3_bar, R.id.event3_text, items.getOrNull(2), theme)
            bindEvent(views, R.id.event4, R.id.event4_bar, R.id.event4_text, items.getOrNull(3), theme)
        }
        val overflow = items.size - maxEvents
        if (overflow > 0) {
            views.setViewVisibility(R.id.more, View.VISIBLE)
            views.setTextColor(R.id.more, theme.textMuted)
            views.setTextViewText(R.id.more, "+$overflow")
        } else {
            views.setViewVisibility(R.id.more, View.GONE)
        }
        return views
    }

    private fun bindEvent(
        views: RemoteViews,
        rootId: Int,
        barId: Int,
        textId: Int,
        item: CalendarItem?,
        theme: CalendarTheme,
    ) {
        if (item == null) {
            views.setViewVisibility(rootId, View.GONE)
            return
        }
        views.setViewVisibility(rootId, View.VISIBLE)
        val color = if (item.done) applyAlpha(item.color, 0.45f) else item.color
        val textColor =
            if (item.allDay && !item.timed) {
                if (item.done) applyAlpha(theme.text, 0.55f) else 0xFFFFFFFF.toInt()
            } else {
                if (item.done) theme.textMuted else theme.text
            }
        views.setTextViewText(textId, item.title)
        views.setTextColor(textId, textColor)
        if (item.allDay && !item.timed) {
            views.setInt(rootId, "setBackgroundColor", color)
            views.setViewVisibility(barId, View.GONE)
        } else {
            views.setInt(rootId, "setBackgroundColor", 0x00000000)
            views.setViewVisibility(barId, View.VISIBLE)
            views.setInt(barId, "setBackgroundColor", color)
        }
    }

    private fun eventRow(
        context: Context,
        item: CalendarItem,
        theme: CalendarTheme,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.calendar_widget_event_row)
        val color = if (item.done) applyAlpha(item.color, 0.45f) else item.color
        views.setInt(R.id.event_bar, "setBackgroundColor", color)
        views.setTextViewText(R.id.event_text, item.title)
        views.setTextColor(R.id.event_text, if (item.done) theme.textMuted else theme.text)
        return views
    }

    private fun launch(
        context: Context,
        action: String,
        date: LocalDate? = null,
    ): PendingIntent {
        val uri =
            Uri.Builder()
                .scheme("principleswidget")
                .authority("calendar")
                .appendQueryParameter("action", action)
                .appendQueryParameter("homeWidget", "true")
                .apply { if (date != null) appendQueryParameter("date", date.toString()) }
                .build()
        return HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri)
    }

    private fun shiftIntent(
        context: Context,
        widgetId: Int,
        unit: String,
        delta: Int,
    ): PendingIntent {
        val intent =
            Intent(context, providerClass(unit)).apply {
                this.action = CalendarWidgetProvider.ACTION_SHIFT
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                putExtra(CalendarWidgetProvider.EXTRA_UNIT, unit)
                putExtra(CalendarWidgetProvider.EXTRA_DELTA, delta)
                data = Uri.parse("principleswidget://shift/$unit/$widgetId/$delta")
            }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getBroadcast(context, widgetId * 20 + delta + 5, intent, flags)
    }

    private fun providerClass(unit: String): Class<*> =
        if (unit == CalendarWidgetProvider.UNIT_WEEK) {
            CalendarWeekWidgetProvider::class.java
        } else {
            CalendarMonthWidgetProvider::class.java
        }

    private fun localeFor(tag: String): Locale =
        if (tag.startsWith("uk")) Locale("uk", "UA") else Locale.ENGLISH
}
