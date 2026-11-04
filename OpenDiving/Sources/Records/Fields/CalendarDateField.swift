import OpenDivingKit
import SwiftUI

/// A day that may be left unset, as the web's date picker leaves it: *Set* opens the wheels on
/// today, the day opens them on itself, and the cross takes it out again.
struct CalendarDateField: View {
  let label: String
  @Binding var date: CalendarDate?

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
      CalendarDateSheet(label: label, date: date) { date = $0 }
    }
  }

  /// The day the phone's calendar shows `instant` on.
  static func calendarDate(_ instant: Date) -> CalendarDate? {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: instant)
    guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
    return CalendarDate(year: year, month: month, day: day)
  }
}

/// The wheels, on the day held or today. *Done* sets the day and a swipe down leaves it as it was.
private struct CalendarDateSheet: View {
  let label: String
  let onDone: (CalendarDate?) -> Void

  @State private var day: Date

  init(label: String, date: CalendarDate?, onDone: @escaping (CalendarDate?) -> Void) {
    self.label = label
    self.onDone = onDone
    let components = date.map { DateComponents(year: $0.year, month: $0.month, day: $0.day) }
    _day = State(initialValue: components.flatMap(Calendar.current.date(from:)) ?? Date())
  }

  var body: some View {
    let picked = CalendarDateField.calendarDate(day)
    WheelSheet(title: label, value: picked.map(DateText.date) ?? "") {
      onDone(picked)
    } wheels: {
      DatePicker(label, selection: $day, displayedComponents: .date)
        .datePickerStyle(.wheel)
        .labelsHidden()
    }
  }
}

#Preview {
  @Previewable @State var date: CalendarDate?
  Form {
    CalendarDateField(label: "Start date", date: $date)
  }
}
