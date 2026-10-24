import OpenDivingKit
import SwiftUI

/// A day that may be left unset, as the web's date picker leaves it: *Set* puts today in,
/// the cross takes it out again.
struct CalendarDateField: View {
  let label: String
  @Binding var date: CalendarDate?

  var body: some View {
    HStack {
      Text(label)
      Spacer()
      if date != nil {
        DatePicker(label, selection: day, displayedComponents: .date)
          .labelsHidden()
        Button {
          date = nil
        } label: {
          Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Clear \(label)")
      } else {
        Button("Set") { date = Self.calendarDate(Date()) }
          .buttonStyle(.borderless)
          .accessibilityLabel("Set \(label)")
      }
    }
  }

  private var day: Binding<Date> {
    Binding(
      get: {
        guard let date else { return Date() }
        let components = DateComponents(year: date.year, month: date.month, day: date.day)
        return Calendar.current.date(from: components) ?? Date()
      },
      set: { date = Self.calendarDate($0) })
  }

  /// The day the phone's calendar shows `instant` on.
  static func calendarDate(_ instant: Date) -> CalendarDate? {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: instant)
    guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
    return CalendarDate(year: year, month: month, day: day)
  }
}

#Preview {
  @Previewable @State var date: CalendarDate?
  Form {
    CalendarDateField(label: "Start date", date: $date)
  }
}
