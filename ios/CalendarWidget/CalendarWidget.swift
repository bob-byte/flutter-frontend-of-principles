import SwiftUI
import WidgetKit

struct CalendarEntry: TimelineEntry {
  let date: Date
  let snapshot: CalendarSnapshot
}

struct CalendarProvider: TimelineProvider {
  func placeholder(in context: Context) -> CalendarEntry {
    CalendarEntry(date: Date(), snapshot: .load())
  }

  func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> Void) {
    completion(CalendarEntry(date: Date(), snapshot: .load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarEntry>) -> Void) {
    let snapshot = CalendarSnapshot.load()
    let entry = CalendarEntry(date: Date(), snapshot: snapshot)
    let nextMidnight = Calendar.current.nextDate(
      after: Date(),
      matching: DateComponents(hour: 0, minute: 1),
      matchingPolicy: .nextTime
    ) ?? Date().addingTimeInterval(3600)
    completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
  }
}

struct CalendarWidgetEntryView: View {
  @Environment(\.widgetFamily) private var family
  var entry: CalendarEntry

  var body: some View {
    let snapshot = entry.snapshot
    Group {
      switch family {
      case .systemSmall:
        TodayWidgetView(snapshot: snapshot)
      case .systemMedium:
        WeekWidgetView(snapshot: snapshot)
      default:
        MonthWidgetView(snapshot: snapshot)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .widgetBackground(snapshot.theme.background)
  }
}

struct MonthWidgetView: View {
  let snapshot: CalendarSnapshot
  private var calendar: Calendar { Calendar.current }

  var body: some View {
    let month = storedVisibleMonth(today: snapshot.today)
    let days = monthGrid(month: month, calendar: calendar, weekStartsOn: snapshot.weekStartsOn)
    let monthIndex = calendar.component(.month, from: month) - 1
    let year = calendar.component(.year, from: month)
    let todayYear = calendar.component(.year, from: snapshot.today)
    let title = snapshot.labels.monthNames.indices.contains(monthIndex)
      ? snapshot.labels.monthNames[monthIndex].uppercased()
      : ""
    VStack(spacing: 4) {
      CalendarHeader(
        title: year == todayYear ? title : "\(title) \(year)",
        snapshot: snapshot,
        unit: "month"
      )
      weekdayRow
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
        ForEach(Array(days.enumerated()), id: \.offset) { _, day in
          let inMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
          Link(destination: principlesCalendarDeepLink(action: "day", date: day)) {
            DayCell(
              day: day,
              snapshot: snapshot,
              inMonth: inMonth,
              maxEvents: 2
            )
          }
        }
      }
    }
  }

  private var weekdayRow: some View {
    HStack(spacing: 0) {
      ForEach(Array(snapshot.labels.weekdays.enumerated()), id: \.offset) { index, label in
        Text(label)
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(index == 6 ? snapshot.theme.sunday : snapshot.theme.textMuted)
          .frame(maxWidth: .infinity)
      }
    }
  }
}

struct WeekWidgetView: View {
  let snapshot: CalendarSnapshot
  private var calendar: Calendar { Calendar.current }

  var body: some View {
    let anchor = storedVisibleWeek(today: snapshot.today)
    let days = weekDays(anchor: anchor, calendar: calendar, weekStartsOn: snapshot.weekStartsOn)
    let first = days.first ?? anchor
    let last = days.last ?? anchor
    let monthIndex = calendar.component(.month, from: first) - 1
    let month = snapshot.labels.monthNamesShort.indices.contains(monthIndex)
      ? snapshot.labels.monthNamesShort[monthIndex].uppercased()
      : ""
    VStack(spacing: 4) {
      CalendarHeader(
        title: "\(month) \(calendar.component(.day, from: first))–\(calendar.component(.day, from: last))",
        snapshot: snapshot,
        unit: "week"
      )
      HStack(spacing: 2) {
        ForEach(Array(days.enumerated()), id: \.offset) { index, day in
          VStack(spacing: 2) {
            Text(snapshot.labels.weekdays.indices.contains(index) ? snapshot.labels.weekdays[index] : "")
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(index == 6 ? snapshot.theme.sunday : snapshot.theme.textMuted)
            Link(destination: principlesCalendarDeepLink(action: "day", date: day)) {
              DayCell(day: day, snapshot: snapshot, inMonth: true, maxEvents: 4)
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
      }
    }
  }
}

struct TodayWidgetView: View {
  let snapshot: CalendarSnapshot
  private var calendar: Calendar { Calendar.current }

  var body: some View {
    let upcoming = snapshot.upcoming(calendar: calendar)
    Link(destination: principlesCalendarDeepLink(action: "today")) {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          VStack(alignment: .leading, spacing: 0) {
            Text(weekdayLabel)
              .font(.system(size: 11, weight: .bold))
              .foregroundStyle(snapshot.theme.textMuted)
            Text("\(calendar.component(.day, from: snapshot.today))")
              .font(.system(size: 28, weight: .bold))
              .foregroundStyle(snapshot.theme.text)
          }
          Spacer()
          Link(destination: principlesCalendarDeepLink(action: "create", date: snapshot.today)) {
            Text("+")
              .font(.system(size: 22, weight: .bold))
              .foregroundStyle(snapshot.theme.primary)
          }
        }
        if upcoming.isEmpty {
          Text(snapshot.labels.empty)
            .font(.system(size: 12))
            .foregroundStyle(snapshot.theme.textMuted)
        } else {
          ForEach(upcoming) { item in
            EventChip(item: item, snapshot: snapshot, compact: false)
          }
        }
        Spacer(minLength: 0)
      }
    }
  }

  private var weekdayLabel: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: snapshot.locale == "uk" ? "uk_UA" : "en")
    formatter.dateFormat = "EEE"
    return formatter.string(from: snapshot.today).uppercased()
  }
}

struct CalendarHeader: View {
  let title: String
  let snapshot: CalendarSnapshot
  let unit: String

  var body: some View {
    HStack(spacing: 4) {
      headerButton(delta: -1, symbol: "chevron.left")
      Text(title)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(snapshot.theme.text)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
      headerButton(delta: 1, symbol: "chevron.right")
      Link(destination: principlesCalendarDeepLink(action: "create", date: snapshot.today)) {
        Text("+")
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(snapshot.theme.primary)
          .frame(width: 24, height: 24)
      }
      todayBadge
    }
  }

  @ViewBuilder
  private func headerButton(delta: Int, symbol: String) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      Button(intent: ShiftCalendarIntent(unit: unit, delta: delta)) {
        Image(systemName: symbol)
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(snapshot.theme.text)
          .frame(width: 24, height: 24)
      }
      .buttonStyle(.plain)
    } else {
      Image(systemName: symbol)
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(snapshot.theme.textMuted)
        .frame(width: 24, height: 24)
    }
  }

  @ViewBuilder
  private var todayBadge: some View {
    let day = Calendar.current.component(.day, from: snapshot.today)
    if #available(iOSApplicationExtension 17.0, *) {
      Button(intent: ShiftCalendarIntent(unit: unit, delta: 0)) {
        Text("\(day)")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(snapshot.theme.todayText)
          .frame(width: 24, height: 24)
          .background(snapshot.theme.todayFill, in: RoundedRectangle(cornerRadius: 6))
      }
      .buttonStyle(.plain)
    } else {
      Link(destination: principlesCalendarDeepLink(action: "today")) {
        Text("\(day)")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(snapshot.theme.todayText)
          .frame(width: 24, height: 24)
          .background(snapshot.theme.todayFill, in: RoundedRectangle(cornerRadius: 6))
      }
    }
  }
}

struct DayCell: View {
  let day: Date
  let snapshot: CalendarSnapshot
  let inMonth: Bool
  let maxEvents: Int
  private var calendar: Calendar { Calendar.current }

  var body: some View {
    let isToday = calendar.isDate(day, inSameDayAs: snapshot.today)
    let items = snapshot.items(on: day, calendar: calendar)
    let number = calendar.component(.day, from: day)
    let sunday = calendar.component(.weekday, from: day) == 1
    VStack(alignment: .leading, spacing: 1) {
      Text("\(number)")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(
          isToday
            ? snapshot.theme.todayText
            : (!inMonth
              ? snapshot.theme.textMuted
              : (sunday ? snapshot.theme.sunday : snapshot.theme.text))
        )
        .frame(width: 18, height: 18)
        .background(
          isToday ? snapshot.theme.todayFill : Color.clear,
          in: RoundedRectangle(cornerRadius: 4)
        )
        .frame(maxWidth: .infinity)
      ForEach(Array(items.prefix(maxEvents))) { item in
        EventChip(item: item, snapshot: snapshot, compact: true)
      }
      if items.count > maxEvents {
        Text("+\(items.count - maxEvents)")
          .font(.system(size: 8, weight: .medium))
          .foregroundStyle(snapshot.theme.textMuted)
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }
}

struct EventChip: View {
  let item: CalendarItem
  let snapshot: CalendarSnapshot
  let compact: Bool

  var body: some View {
    let color = item.done ? item.color.opacity(0.45) : item.color
    let textColor =
      item.allDay && !item.timed
      ? (item.done ? snapshot.theme.text.opacity(0.55) : Color.white)
      : (item.done ? snapshot.theme.textMuted : snapshot.theme.text)
    HStack(spacing: 2) {
      if item.timed || !item.allDay {
        Capsule()
          .fill(color)
          .frame(width: 2, height: compact ? 9 : 11)
      }
      Text(item.title)
        .font(.system(size: compact ? 8 : 12, weight: .medium))
        .foregroundStyle(textColor)
        .lineLimit(1)
    }
    .padding(.horizontal, item.allDay && !item.timed ? 2 : 0)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      item.allDay && !item.timed ? color : Color.clear,
      in: RoundedRectangle(cornerRadius: 3)
    )
  }
}

@main
struct CalendarWidget: Widget {
  let kind = "CalendarWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: CalendarProvider()) { entry in
      CalendarWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Calendar")
    .description("Tasks and habits on your Home Screen")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

extension View {
  @ViewBuilder
  func widgetBackground(_ color: Color) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(for: .widget) { color }
    } else {
      background(color)
    }
  }
}
