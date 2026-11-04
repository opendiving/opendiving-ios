import SwiftUI

/// A time zone chosen from every zone the phone knows, by its identifier, and the selection
/// where the phone does not know it: the download's question, offering a watch that reports only
/// an offset, whose *GMT+0400* is no known identifier and would otherwise leave the row blank.
struct TimeZonePicker: View {
  let title: String
  @Binding var selection: TimeZone

  var body: some View {
    Picker(title, selection: identifier) {
      ForEach(Self.identifiers(showing: selection), id: \.self) { identifier in
        Text(identifier.replacingOccurrences(of: "_", with: " ")).tag(identifier)
      }
    }
    .pickerStyle(.navigationLink)
  }

  static func identifiers(showing selection: TimeZone) -> [String] {
    let known = TimeZone.knownTimeZoneIdentifiers
    return known.contains(selection.identifier) ? known : [selection.identifier] + known
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
