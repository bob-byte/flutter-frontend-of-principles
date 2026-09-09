package com.set.principles.calendar

import android.graphics.Color
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate

data class CalendarTheme(
    val isDark: Boolean,
    val background: Int,
    val text: Int,
    val textMuted: Int,
    val primary: Int,
    val onPrimary: Int,
    val divider: Int,
    val sunday: Int,
    val todayFill: Int,
    val todayText: Int,
)

data class CalendarLabels(
    val today: String,
    val add: String,
    val empty: String,
    val monthNames: List<String>,
    val monthNamesShort: List<String>,
    val weekdays: List<String>,
)

data class CalendarItem(
    val id: String,
    val kind: String,
    val title: String,
    val start: LocalDate,
    val end: LocalDate,
    val allDay: Boolean,
    val timed: Boolean,
    val color: Int,
    val done: Boolean,
) {
    fun occursOn(day: LocalDate): Boolean = !day.isBefore(start) && !day.isAfter(end)
}

data class CalendarSnapshot(
    val locale: String,
    val today: LocalDate,
    val weekStartsOn: Int,
    val theme: CalendarTheme,
    val labels: CalendarLabels,
    val items: List<CalendarItem>,
) {
    fun itemsOn(day: LocalDate): List<CalendarItem> =
        items
            .filter { it.occursOn(day) }
            .sortedWith(
                compareBy<CalendarItem> { it.done }
                    .thenByDescending { it.allDay }
                    .thenBy { it.title.lowercase() },
            )

    fun upcoming(limit: Int = 4): List<CalendarItem> {
        val seen = mutableSetOf<String>()
        val result = ArrayList<CalendarItem>()
        var cursor = today
        val end = today.plusDays(7)
        while (!cursor.isAfter(end) && result.size < limit) {
            for (item in itemsOn(cursor)) {
                if (item.done) continue
                if (!seen.add(item.id)) continue
                result.add(item)
                if (result.size >= limit) break
            }
            cursor = cursor.plusDays(1)
        }
        return result
    }
}

object CalendarSnapshotParser {
    fun parse(raw: String?): CalendarSnapshot {
        val json = raw?.takeIf { it.isNotBlank() }?.let { JSONObject(it) }
        val today = parseDate(json?.optString("today")) ?: LocalDate.now()
        val themeJson = json?.optJSONObject("theme")
        val labelsJson = json?.optJSONObject("labels")
        return CalendarSnapshot(
            locale = json?.optString("locale")?.ifBlank { null } ?: "uk",
            today = today,
            weekStartsOn = json?.optInt("weekStartsOn", 1) ?: 1,
            theme = CalendarTheme(
                isDark = themeJson?.optBoolean("isDark", true) ?: true,
                background = parseColor(themeJson?.optString("background"), 0xFF121212.toInt()),
                text = parseColor(themeJson?.optString("text"), 0xFFFFFFFF.toInt()),
                textMuted = parseColor(themeJson?.optString("textMuted"), 0x80FFFFFF.toInt()),
                primary = parseColor(themeJson?.optString("primary"), 0xFFFF6B00.toInt()),
                onPrimary = parseColor(themeJson?.optString("onPrimary"), 0xFF180C06.toInt()),
                divider = parseColor(themeJson?.optString("divider"), 0xFF222222.toInt()),
                sunday = parseColor(themeJson?.optString("sunday"), 0xFFFF6B00.toInt()),
                todayFill = parseColor(themeJson?.optString("todayFill"), 0xFFFFFFFF.toInt()),
                todayText = parseColor(themeJson?.optString("todayText"), 0xFF181818.toInt()),
            ),
            labels = CalendarLabels(
                today = labelsJson?.optString("today")?.ifBlank { null } ?: "Today",
                add = labelsJson?.optString("add")?.ifBlank { null } ?: "+",
                empty = labelsJson?.optString("empty")?.ifBlank { null } ?: "",
                monthNames = stringList(labelsJson?.optJSONArray("monthNames"), DEFAULT_MONTHS),
                monthNamesShort =
                    stringList(labelsJson?.optJSONArray("monthNamesShort"), DEFAULT_MONTHS_SHORT),
                weekdays = stringList(labelsJson?.optJSONArray("weekdays"), DEFAULT_WEEKDAYS),
            ),
            items = parseItems(json?.optJSONArray("items")),
        )
    }

    fun parseColor(hex: String?, fallback: Int): Int {
        val value = hex?.trim().orEmpty()
        if (value.isEmpty()) return fallback
        return try {
            Color.parseColor(value)
        } catch (_: Exception) {
            fallback
        }
    }

    fun parseDate(raw: String?): LocalDate? {
        val value = raw?.trim().orEmpty()
        if (value.length < 10) return null
        return try {
            LocalDate.parse(value.substring(0, 10))
        } catch (_: Exception) {
            null
        }
    }

    private fun parseItems(array: JSONArray?): List<CalendarItem> {
        if (array == null) return emptyList()
        val items = ArrayList<CalendarItem>(array.length())
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            val start = parseDate(obj.optString("start")) ?: continue
            val end = parseDate(obj.optString("end")) ?: start
            items.add(
                CalendarItem(
                    id = obj.optString("id"),
                    kind = obj.optString("kind", "task"),
                    title = obj.optString("title"),
                    start = start,
                    end = if (end.isBefore(start)) start else end,
                    allDay = obj.optBoolean("allDay"),
                    timed = obj.optBoolean("timed"),
                    color = parseColor(obj.optString("color"), 0xFF007BFF.toInt()),
                    done = obj.optBoolean("done"),
                ),
            )
        }
        return items
    }

    private fun stringList(array: JSONArray?, fallback: List<String>): List<String> {
        if (array == null || array.length() < fallback.size) return fallback
        return List(fallback.size) { array.optString(it, fallback[it]) }
    }

    private val DEFAULT_MONTHS =
        listOf(
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December",
        )
    private val DEFAULT_MONTHS_SHORT =
        listOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
    private val DEFAULT_WEEKDAYS = listOf("MO", "TU", "WE", "TH", "FR", "SA", "SU")
}

fun applyAlpha(color: Int, fraction: Float): Int {
    val alpha = ((Color.alpha(color) * fraction).toInt()).coerceIn(0, 255)
    return Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
}

fun monthGrid(month: LocalDate, weekStartsOn: Int = 1): List<LocalDate> {
    val first = month.withDayOfMonth(1)
    val startOffset = Math.floorMod(first.dayOfWeek.value - weekStartsOn, 7)
    val start = first.minusDays(startOffset.toLong())
    return List(42) { start.plusDays(it.toLong()) }
}

fun weekDays(anchor: LocalDate, weekStartsOn: Int = 1): List<LocalDate> {
    val startOffset = Math.floorMod(anchor.dayOfWeek.value - weekStartsOn, 7)
    val start = anchor.minusDays(startOffset.toLong())
    return List(7) { start.plusDays(it.toLong()) }
}
