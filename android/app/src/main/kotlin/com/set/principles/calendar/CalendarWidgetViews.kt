package com.set.principles.calendar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Parcel
import android.util.Log
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
    private const val TAG = "CalendarWidget"
    /** Soft ceiling — Samsung One UI often rejects larger oneway binder pushes. */
    private const val MAX_SAFE_BYTES = 180_000

    fun build(
        context: Context,
        widgetId: Int,
        kind: CalendarWidgetKind,
        snapshot: CalendarSnapshot,
    ): RemoteViews {
        val full =
            when (kind) {
                CalendarWidgetKind.TODAY -> buildToday(context, snapshot, withEvents = true)
                CalendarWidgetKind.WEEK ->
                    buildCalendar(context, widgetId, snapshot, week = true, withEvents = true)
                CalendarWidgetKind.MONTH ->
                    buildCalendar(context, widgetId, snapshot, week = false, withEvents = true)
            }
        val fullSize = parcelSize(full)
        if (fullSize <= MAX_SAFE_BYTES) {
            Log.d(TAG, "RemoteViews kind=$kind size=$fullSize")
            return full
        }
        Log.w(TAG, "RemoteViews kind=$kind size=$fullSize too large; stripping event chips")
        val lite =
            when (kind) {
                CalendarWidgetKind.TODAY -> buildToday(context, snapshot, withEvents = false)
                CalendarWidgetKind.WEEK ->
                    buildCalendar(context, widgetId, snapshot, week = true, withEvents = false)
                CalendarWidgetKind.MONTH ->
                    buildCalendar(context, widgetId, snapshot, week = false, withEvents = false)
            }
        Log.d(TAG, "RemoteViews kind=$kind lite size=${parcelSize(lite)}")
        return lite
    }

    private fun buildToday(
        context: Context,
        snapshot: CalendarSnapshot,
        withEvents: Boolean,
    ): RemoteViews {
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
        val upcoming = if (withEvents) snapshot.upcoming() else emptyList()
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
        withEvents: Boolean,
    ): RemoteViews {
        val layout = if (week) R.layout.calendar_widget_week else R.layout.calendar_widget_month
        val views = RemoteViews(context.packageName, layout)
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

        for (index in 0 until 7) {
            val wdId = id(context, "wd_$index")
            val text = snapshot.labels.weekdays.getOrElse(index) { "" }
            val sunday = index == 6
            views.setTextViewText(wdId, text)
            views.setTextColor(wdId, if (sunday) theme.sunday else theme.textMuted)
        }

        val days = if (week) weekDays(anchor, snapshot.weekStartsOn) else monthGrid(anchor, snapshot.weekStartsOn)
        val rows = if (week) 1 else 6
        val maxEvents = if (week) 4 else 2
        for (row in 0 until rows) {
            for (col in 0 until 7) {
                val day = days[row * 7 + col]
                bindDayCell(
                    context,
                    views,
                    snapshot,
                    day,
                    week = week,
                    row = row,
                    col = col,
                    maxEvents = maxEvents,
                    inMonth = day.month == anchor.month,
                    withEvents = withEvents,
                )
            }
        }
        return views
    }

    private fun bindDayCell(
        context: Context,
        views: RemoteViews,
        snapshot: CalendarSnapshot,
        day: LocalDate,
        week: Boolean,
        row: Int,
        col: Int,
        maxEvents: Int,
        inMonth: Boolean,
        withEvents: Boolean,
    ) {
        val theme = snapshot.theme
        val prefix = if (week) "wday_$col" else "day_${row}_$col"
        val rootId = id(context, prefix)
        val numId = id(context, "${prefix}_num")
        val moreId = id(context, "${prefix}_more")
        val isToday = day == snapshot.today
        val numberColor =
            when {
                isToday -> theme.todayText
                !inMonth -> theme.textMuted
                day.dayOfWeek.value == 7 -> theme.sunday
                else -> theme.text
            }
        views.setTextViewText(numId, day.dayOfMonth.toString())
        views.setTextColor(numId, numberColor)
        views.setInt(
            numId,
            "setBackgroundColor",
            if (isToday) theme.todayFill else 0x00000000,
        )
        views.setOnClickPendingIntent(rootId, launch(context, action = "day", date = day))

        val items = if (withEvents) snapshot.itemsOn(day) else emptyList()
        for (i in 1..maxEvents) {
            bindEventChip(
                views,
                id(context, "${prefix}_e$i"),
                items.getOrNull(i - 1),
                theme,
            )
        }
        val overflow = items.size - maxEvents
        if (overflow > 0) {
            views.setViewVisibility(moreId, View.VISIBLE)
            views.setTextColor(moreId, theme.textMuted)
            views.setTextViewText(moreId, "+$overflow")
        } else {
            views.setViewVisibility(moreId, View.GONE)
        }
    }

    private fun bindEventChip(
        views: RemoteViews,
        textId: Int,
        item: CalendarItem?,
        theme: CalendarTheme,
    ) {
        if (item == null) {
            views.setViewVisibility(textId, View.GONE)
            return
        }
        views.setViewVisibility(textId, View.VISIBLE)
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
            views.setInt(textId, "setBackgroundColor", color)
        } else {
            views.setInt(textId, "setBackgroundColor", 0x00000000)
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
        // Unique request codes: HomeWidgetLaunchIntent always uses 0, which would
        // collapse every day/create tap onto the last PendingIntent.
        // Skip ActivityOptions bundles — attaching one to every day cell balloons
        // the RemoteViews parcel past Samsung One UI's practical binder limit.
        val intent =
            Intent(context, MainActivity::class.java).apply {
                this.action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                data = uri
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        val requestCode = (action.hashCode() * 31) + (date?.toEpochDay()?.toInt() ?: 0)
        return PendingIntent.getActivity(context, requestCode, intent, flags)
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

    private fun id(context: Context, name: String): Int =
        context.resources.getIdentifier(name, "id", context.packageName)

    private fun parcelSize(views: RemoteViews): Int {
        val parcel = Parcel.obtain()
        return try {
            views.writeToParcel(parcel, 0)
            parcel.dataSize()
        } finally {
            parcel.recycle()
        }
    }

    private fun localeFor(tag: String): Locale =
        if (tag.startsWith("uk")) Locale("uk", "UA") else Locale.ENGLISH
}
