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
    box("Latitude", "e.g. 27.8506", $latitude, latitudeMessage)
    box("Longitude", "e.g. 34.3136", $longitude, longitudeMessage)
    Text(hint).font(.footnote).foregroundStyle(.secondary)
  }

  private func box(_ label: String, _ example: String, _ text: Binding<String>, _ message: String?)
    -> some View
  {
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.subheadline.weight(.medium))
      TextField(label, text: text, prompt: Text(example))
        .keyboardType(.numbersAndPunctuation)
        .autocorrectionDisabled()
        .labelsHidden()
        .accessibilityHint(hint)
        .onChange(of: text.wrappedValue) { old, new in split(old, new, into: text) }
      FieldMessage(text: message)
    }
  }

  /// Typing adds a character at a time, so only a change of several at once is a paste —
  /// otherwise `27.8 3` would split as it was being typed.
  private func split(_ old: String, _ new: String, into text: Binding<String>) {
    guard new.count - old.count > 1, let pair = PlaceSearch.coordinatePair(new) else { return }
    latitude = pair.latitude
    longitude = pair.longitude
    onPlaced?(pair.latitude, pair.longitude)
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
