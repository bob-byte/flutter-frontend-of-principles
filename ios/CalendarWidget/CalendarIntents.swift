import AppIntents
import Foundation
import WidgetKit

@available(iOS 17.0, *)
struct ShiftCalendarIntent: AppIntent {
  static var title: LocalizedStringResource = "Shift calendar"
  static var isDiscoverable = false

  @Parameter(title: "Unit")
  var unit: String

  @Parameter(title: "Delta")
  var delta: Int

  init() {
    unit = "month"
    delta = 0
  }

  init(unit: String, delta: Int) {
    self.unit = unit
    self.delta = delta
  }

  func perform() async throws -> some IntentResult {
    let defaults = UserDefaults(suiteName: calendarAppGroupId)
    let snapshot = CalendarSnapshot.load()
    let calendar = Calendar.current
    if unit == "week" {
      let current =
        parseDate(defaults?.string(forKey: calendarVisibleWeekKey)) ?? snapshot.today
      let next =
        delta == 0
        ? snapshot.today
        : (calendar.date(byAdding: .day, value: delta * 7, to: current) ?? current)
      defaults?.set(isoDate(next), forKey: calendarVisibleWeekKey)
    } else {
      let current =
        parseDate(defaults?.string(forKey: calendarVisibleMonthKey)) ?? snapshot.today
      let next =
        delta == 0
        ? snapshot.today
        : (calendar.date(byAdding: .month, value: delta, to: current) ?? current)
      defaults?.set(isoDate(next), forKey: calendarVisibleMonthKey)
    }
    WidgetCenter.shared.reloadTimelines(ofKind: "CalendarWidget")
    return .result()
  }
}

func isoDate(_ date: Date) -> String {
  let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
  return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
}

func storedVisibleMonth(today: Date) -> Date {
  let raw = UserDefaults(suiteName: calendarAppGroupId)?.string(forKey: calendarVisibleMonthKey)
  return parseDate(raw) ?? today
}

func storedVisibleWeek(today: Date) -> Date {
  let raw = UserDefaults(suiteName: calendarAppGroupId)?.string(forKey: calendarVisibleWeekKey)
  return parseDate(raw) ?? today
}
