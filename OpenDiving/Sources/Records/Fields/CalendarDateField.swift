import OpenDivingKit
import SwiftUI

/// A day that may be left unset, as the web's date picker leaves it: *Set* opens the wheels on
/// today, or on the other half of a start and end pair, the day opens them on itself, and the
/// cross takes it out again. A half names the other: `rangeStart` on the end, `rangeEnd` on the
/// start.
struct CalendarDateField: View {
  let label: String
  @Binding var date: CalendarDate?
  var rangeStart: CalendarDate?
  var rangeEnd: CalendarDate?

  @State private var picking = false

  var body: some View {
    HStack {
      Text(label)
      Spacer()
      if let date {
        Button {
          picking = true
        } label: {
          Text(DateText.date(date)).foregroundStyle(Color.secondary)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("\(label), \(DateText.date(date))")
        Button {
          self.date = nil
        } label: {
          Image(systemName: "xmark.circle.fill").foregroundStyle(Color.secondary)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Clear \(label)")
      } else {
        Button("Set") { picking = true }
          .accentRow()
          .buttonStyle(.borderless)
          .accessibilityLabel("Set \(label)")
      }
    }
    .sheet(isPresented: $picking) {
      CalendarDateSheet(
        label: label,
        wheels: CalendarDateWheels(held: date, rangeStart: rangeStart, rangeEnd: rangeEnd)
      ) { date = $0 }
    }
  }

  /// The instant the phone's calendar starts `day` at.
  static func instant(_ day: CalendarDate) -> Date? {
    Calendar.current.date(
      from: DateComponents(year: day.year, month: day.month, day: day.day))
  }

  /// The day the phone's calendar shows `instant` on.
  static func calendarDate(_ instant: Date) -> CalendarDate? {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: instant)
    guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
    return CalendarDate(year: year, month: month, day: day)
  }
}

/// The wheels, on the day they open on. *Done* sets the day and a swipe down leaves it as it was.
private struct CalendarDateSheet: View {
  let label: String
  let note: String?
  let earliest: Date
  let onDone: (CalendarDate?) -> Void

  @State private var day: Date

  init(label: String, wheels: CalendarDateWheels, onDone: @escaping (CalendarDate?) -> Void) {
    self.label = label
    self.note = wheels.note
    self.earliest = wheels.earliest.flatMap(CalendarDateField.instant) ?? .distantPast
    self.onDone = onDone
    _day = State(initialValue: wheels.opensOn.flatMap(CalendarDateField.instant) ?? Date())
  }

  var body: some View {
    let picked = CalendarDateField.calendarDate(day)
    WheelSheet(title: label, value: picked.map(DateText.date) ?? "", note: note) {
      onDone(picked)
    } wheels: {
      DatePicker(label, selection: $day, in: earliest..., displayedComponents: .date)
        .datePickerStyle(.wheel)
        .labelsHidden()
    }
  }
}

#Preview {
  @Previewable @State var start = CalendarDate(year: 2024, month: 6, day: 1)
  @Previewable @State var end: CalendarDate?
  Form {
    CalendarDateField(label: "Start date", date: $start, rangeEnd: end)
    CalendarDateField(label: "End date", date: $end, rangeStart: start)
  }
}
