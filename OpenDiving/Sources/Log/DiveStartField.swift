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
      if let start { StartTimeSheet(start: start, onDone: onChange) }
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

/// The wheels, in the dive's own offset. A dive that records only its day turns only days.
private struct StartTimeSheet: View {
  let start: DiveTimestamp
  let zone: TimeZone
  let onDone: (DiveTimestamp?) -> Void

  @State private var date: Date

  init(start: DiveTimestamp, onDone: @escaping (DiveTimestamp?) -> Void) {
    let (date, zone) = DiveStart.pickerValue(start)
    self.start = start
    self.zone = zone
    self.onDone = onDone
    _date = State(initialValue: date)
  }

  var body: some View {
    let picked = DiveStart.picking(date, in: zone, keeping: start)
    WheelSheet(title: "Start time", value: DateText.diveDateTime(picked)) {
      onDone(picked)
    } wheels: {
      DatePicker(
        "Date and time", selection: $date,
        displayedComponents: isDay ? [.date] : [.date, .hourAndMinute]
      )
      .datePickerStyle(.wheel)
      .labelsHidden()
      .environment(\.timeZone, zone)
    }
  }

  private var isDay: Bool {
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
