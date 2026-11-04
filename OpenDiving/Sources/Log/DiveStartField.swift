import OpenDivingKit
import SwiftUI

/// The start: a row showing the date and the clock the diver saw, which opens the wheels that set
/// them, and the offset in a row of its own, since a row holding a menu opens it wherever it is
/// tapped. A dive that records only its day is picked as a day.
struct DiveStartField: View {
  let title: String
  let start: DiveTimestamp?
  let offsets: [Int?]
  var error: String?
  let onChange: (DiveTimestamp?) -> Void

  @State private var picking = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let start {
        WheelRow(title: title, value: DateText.diveDateTime(start)) { picking = true }
      } else {
        FieldLabel(title)
        Button("Set the start time") { onChange(DiveStart.now()) }
      }
      if let error { FieldMessage(error) }
    }
    .sheet(isPresented: $picking) {
      if let start {
        let (date, zone) = DiveStart.pickerValue(start)
        WheelSheet(title: "Start time", value: DateText.diveDateTime(start)) {
          DatePicker(
            "Date and time",
            selection: Binding(
              get: { date },
              set: { onChange(DiveStart.picking($0, in: zone, keeping: start)) }),
            displayedComponents: isDay(start) ? [.date] : [.date, .hourAndMinute]
          )
          .datePickerStyle(.wheel)
          .labelsHidden()
          .environment(\.timeZone, zone)
        }
      }
    }
    if let start {
      Picker(
        "UTC offset",
        selection: Binding(
          get: { start.utcOffsetMinutes },
          set: { onChange(DiveStart.withOffset($0, start)) })
      ) {
        ForEach(offsets, id: \.self) { minutes in
          Text(DiveStart.offsetLabel(minutes)).tag(minutes)
        }
      }
      .disabled(isDay(start))
    }
  }

  private func isDay(_ start: DiveTimestamp) -> Bool {
    if case .day = start { true } else { false }
  }
}

#Preview {
  Form {
    DiveStartField(
      title: "Start time *", start: DiveStart.now(), offsets: DiveStart.offsetChoices()
    ) { _ in }
  }
}
