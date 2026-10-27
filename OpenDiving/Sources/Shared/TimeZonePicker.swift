import SwiftUI

/// A time zone chosen from every zone the phone knows, by its identifier: the download's
/// question and a remembered computer's zone in Settings.
struct TimeZonePicker: View {
  let title: String
  @Binding var selection: TimeZone

  var body: some View {
    Picker(title, selection: identifier) {
      ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { identifier in
        Text(identifier.replacingOccurrences(of: "_", with: " ")).tag(identifier)
      }
    }
    .pickerStyle(.navigationLink)
  }

  private var identifier: Binding<String> {
    Binding(
      get: { selection.identifier },
      set: { selection = TimeZone(identifier: $0) ?? selection })
  }
}

#Preview {
  @Previewable @State var zone = TimeZone(identifier: "Europe/Berlin")!
  NavigationStack {
    Form {
      TimeZonePicker(title: "Time zone", selection: $zone)
    }
  }
}
