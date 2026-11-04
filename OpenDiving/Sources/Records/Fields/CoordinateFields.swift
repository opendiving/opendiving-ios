import OpenDivingKit
import SwiftUI

/// A latitude and a longitude box and the hint they share. A `27.8506, 34.3136` pair pasted
/// into either fills both and is reported as a placed position, as the web's paste handler
/// does; the full keyboard, since the decimal keypad has no minus.
struct CoordinateFields: View {
  @Binding var latitude: String
  @Binding var longitude: String
  var latitudeMessage: String?
  var longitudeMessage: String?
  let hint: String
  /// A pair arrived whole, by paste.
  var onPlaced: ((String, String) -> Void)?

  var body: some View {
    CoordinateBox(
      label: "Latitude", example: "e.g. 27.8506", text: $latitude, message: latitudeMessage,
      hint: hint, onChange: split)
    CoordinateBox(
      label: "Longitude", example: "e.g. 34.3136", text: $longitude, message: longitudeMessage,
      hint: hint, onChange: split)
    Text(hint).font(.footnote).foregroundStyle(.secondary)
  }

  /// Typing adds a character at a time, so only a change of several at once is a paste —
  /// otherwise `27.8 3` would split as it was being typed.
  private func split(_ old: String, _ new: String) {
    guard new.count - old.count > 1, let pair = PlaceSearch.coordinatePair(new) else { return }
    latitude = pair.latitude
    longitude = pair.longitude
    onPlaced?(pair.latitude, pair.longitude)
  }
}

/// One of the two boxes.
private struct CoordinateBox: View {
  let label: String
  let example: String
  @Binding var text: String
  let message: String?
  let hint: String
  let onChange: (String, String) -> Void

  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      FieldLabel(label)
        .focusesOnTap($focused)
      TextField(label, text: $text, prompt: Text(example))
        .keyboardType(.numbersAndPunctuation)
        .autocorrectionDisabled()
        .labelsHidden()
        .focused($focused)
        .accessibilityHint(hint)
        .onChange(of: text) { old, new in onChange(old, new) }
      FieldMessage(message)
    }
  }
}

#Preview {
  @Previewable @State var latitude = ""
  @Previewable @State var longitude = ""
  Form {
    CoordinateFields(
      latitude: $latitude, longitude: $longitude,
      hint: "Paste a “27.8506, 34.3136” pair into either field to fill both.")
  }
}
