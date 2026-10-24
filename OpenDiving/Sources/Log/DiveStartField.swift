import OpenDivingKit
import SwiftUI

/// The start: the date and the clock the diver saw, picked in the dive's own offset, and the
/// offset beside it. A dive that records only its day is picked as a day.
struct DiveStartField: View {
  let title: String
  let start: DiveTimestamp?
  let offsets: [Int?]
  var error: String?
  let onChange: (DiveTimestamp?) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      FieldLabel(title)
      if let start {
        let (date, zone) = DiveStart.pickerValue(start)
        DatePicker(
          "Date and time",
          selection: Binding(
            get: { date },
            set: { onChange(DiveStart.picking($0, in: zone, keeping: start)) }),
          displayedComponents: isDay(start) ? [.date] : [.date, .hourAndMinute]
        )
        .labelsHidden()
        .environment(\.timeZone, zone)
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
      } else {
        Button("Set the start time") { onChange(DiveStart.now()) }
      }
      if let error { FieldMessage(error) }
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
