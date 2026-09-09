import SwiftUI
import WidgetKit

let calendarAppGroupId = "group.com.set.principles"
let calendarSnapshotKey = "calendar_snapshot"
let calendarVisibleMonthKey = "calendar_visible_month"
let calendarVisibleWeekKey = "calendar_visible_week"

struct CalendarTheme {
  var isDark: Bool
  var background: Color
  var text: Color
  var textMuted: Color
  var primary: Color
  var onPrimary: Color
  var divider: Color
  var sunday: Color
  var todayFill: Color
  var todayText: Color
}

struct CalendarLabels {
  var today: String
  var add: String
  var empty: String
  var monthNames: [String]
  var monthNamesShort: [String]
  var weekdays: [String]
}

struct CalendarItem: Identifiable {
  var id: String
  var kind: String
  var title: String
  var start: Date
  var end: Date
  var allDay: Bool
  var timed: Bool
  var color: Color
  var done: Bool

  func occurs(on day: Date, calendar: Calendar) -> Bool {
    let startDay = calendar.startOfDay(for: start)
    let endDay = calendar.startOfDay(for: end)
    let dayStart = calendar.startOfDay(for: day)
    return dayStart >= startDay && dayStart <= endDay
  }
}

struct CalendarSnapshot {
  var locale: String
  var today: Date
  var weekStartsOn: Int
  var theme: CalendarTheme
  var labels: CalendarLabels
  var items: [CalendarItem]

  func items(on day: Date, calendar: Calendar) -> [CalendarItem] {
    items
      .filter { $0.occurs(on: day, calendar: calendar) }
      .sorted { lhs, rhs in
        if lhs.done != rhs.done { return !lhs.done && rhs.done }
        if lhs.allDay != rhs.allDay { return lhs.allDay && !rhs.allDay }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
      }
  }

  func upcoming(limit: Int = 4, calendar: Calendar) -> [CalendarItem] {
    var seen = Set<String>()
    var result: [CalendarItem] = []
    var cursor = calendar.startOfDay(for: today)
    let end = calendar.date(byAdding: .day, value: 7, to: cursor) ?? cursor
    while cursor <= end && result.count < limit {
      for item in items(on: cursor, calendar: calendar) where !item.done {
        if seen.insert(item.id).inserted {
          result.append(item)
          if result.count >= limit { return result }
        }
      }
      cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? end.addingTimeInterval(1)
    }
    return result
  }

  static func load() -> CalendarSnapshot {
    let defaults = UserDefaults(suiteName: calendarAppGroupId)
    let raw = defaults?.string(forKey: calendarSnapshotKey)
    return parse(raw)
  }

  static func parse(_ raw: String?) -> CalendarSnapshot {
    let json = (raw?.data(using: .utf8)).flatMap {
      try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
    }
    let theme = json?["theme"] as? [String: Any]
    let labels = json?["labels"] as? [String: Any]
    let today = parseDate(json?["today"] as? String) ?? Calendar.current.startOfDay(for: Date())
    return CalendarSnapshot(
      locale: json?["locale"] as? String ?? "uk",
      today: today,
      weekStartsOn: json?["weekStartsOn"] as? Int ?? 1,
      theme: CalendarTheme(
        isDark: theme?["isDark"] as? Bool ?? true,
        background: color(theme?["background"] as? String, fallback: Color(red: 0.07, green: 0.07, blue: 0.07)),
        text: color(theme?["text"] as? String, fallback: .white),
        textMuted: color(theme?["textMuted"] as? String, fallback: Color.white.opacity(0.5)),
        primary: color(theme?["primary"] as? String, fallback: Color(red: 1, green: 0.42, blue: 0)),
        onPrimary: color(theme?["onPrimary"] as? String, fallback: Color(red: 0.09, green: 0.05, blue: 0.02)),
        divider: color(theme?["divider"] as? String, fallback: Color(white: 0.13)),
        sunday: color(theme?["sunday"] as? String, fallback: Color(red: 1, green: 0.42, blue: 0)),
        todayFill: color(theme?["todayFill"] as? String, fallback: .white),
        todayText: color(theme?["todayText"] as? String, fallback: Color(white: 0.1))
      ),
      labels: CalendarLabels(
        today: labels?["today"] as? String ?? "Today",
        add: labels?["add"] as? String ?? "Add",
        empty: labels?["empty"] as? String ?? "",
        monthNames: stringList(labels?["monthNames"], fallback: defaultMonths),
        monthNamesShort: stringList(labels?["monthNamesShort"], fallback: defaultMonthsShort),
        weekdays: stringList(labels?["weekdays"], fallback: defaultWeekdays)
      ),
      items: parseItems(json?["items"] as? [[String: Any]] ?? [])
    )
  }
}

func parseItems(_ raw: [[String: Any]]) -> [CalendarItem] {
  raw.compactMap { obj in
    guard let start = parseDate(obj["start"] as? String) else { return nil }
    let end = parseDate(obj["end"] as? String) ?? start
    return CalendarItem(
      id: obj["id"] as? String ?? UUID().uuidString,
      kind: obj["kind"] as? String ?? "task",
      title: obj["title"] as? String ?? "",
      start: start,
      end: end < start ? start : end,
      allDay: obj["allDay"] as? Bool ?? false,
      timed: obj["timed"] as? Bool ?? false,
      color: color(obj["color"] as? String, fallback: Color.blue),
      done: obj["done"] as? Bool ?? false
    )
  }
}

func parseDate(_ raw: String?) -> Date? {
  guard let raw, raw.count >= 10 else { return nil }
  let parts = raw.prefix(10).split(separator: "-").compactMap { Int($0) }
  guard parts.count == 3 else { return nil }
  return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
}

func color(_ hex: String?, fallback: Color) -> Color {
  guard var value = hex?.trimmingCharacters(in: CharacterSet(charactersIn: "#")) else {
    return fallback
  }
  if value.count == 6 { value = "FF" + value }
  guard value.count == 8, let int = UInt32(value, radix: 16) else { return fallback }
  let a = Double((int >> 24) & 0xFF) / 255
  let r = Double((int >> 16) & 0xFF) / 255
  let g = Double((int >> 8) & 0xFF) / 255
  let b = Double(int & 0xFF) / 255
  return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
}

func stringList(_ raw: Any?, fallback: [String]) -> [String] {
  guard let list = raw as? [String], list.count >= fallback.count else { return fallback }
  return Array(list.prefix(fallback.count))
}

/// ISO weekday: Monday=1 … Sunday=7 (matches Android/Dart `weekStartsOn`).
func isoWeekday(from date: Date, calendar: Calendar) -> Int {
  let weekday = calendar.component(.weekday, from: date) // 1=Sun … 7=Sat
  return weekday == 1 ? 7 : weekday - 1
}

func startOffset(for date: Date, calendar: Calendar, weekStartsOn: Int) -> Int {
  let iso = isoWeekday(from: date, calendar: calendar)
  // floorMod so Sunday-first (weekStartsOn=7) works when iso < weekStartsOn
  return ((iso - weekStartsOn) % 7 + 7) % 7
}

func monthGrid(month: Date, calendar: Calendar, weekStartsOn: Int = 1) -> [Date] {
  let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
  let offset = startOffset(for: startOfMonth, calendar: calendar, weekStartsOn: weekStartsOn)
  let start = calendar.date(byAdding: .day, value: -offset, to: startOfMonth) ?? startOfMonth
  return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
}

func weekDays(anchor: Date, calendar: Calendar, weekStartsOn: Int = 1) -> [Date] {
  let day = calendar.startOfDay(for: anchor)
  let offset = startOffset(for: day, calendar: calendar, weekStartsOn: weekStartsOn)
  let start = calendar.date(byAdding: .day, value: -offset, to: day) ?? day
  return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
}

/// Deep link into the Flutter app. Named distinctly from SwiftUI's `widgetURL` modifier.
func principlesCalendarDeepLink(action: String, date: Date? = nil) -> URL {
  var components = URLComponents()
  components.scheme = "principleswidget"
  components.host = "calendar"
  var items = [
    URLQueryItem(name: "action", value: action),
    URLQueryItem(name: "homeWidget", value: "true"),
  ]
  if let date {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
    let y = parts.year ?? 0
    let m = String(format: "%02d", parts.month ?? 0)
    let d = String(format: "%02d", parts.day ?? 0)
    items.append(URLQueryItem(name: "date", value: "\(y)-\(m)-\(d)"))
  }
  components.queryItems = items
  return components.url ?? URL(string: "principleswidget://calendar?action=\(action)")!
}

private let defaultMonths = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
]
private let defaultMonthsShort = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
]
private let defaultWeekdays = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
