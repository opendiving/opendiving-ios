import OpenDivingKit
import SwiftUI

/// The legend and the control for what is plotted: one switch per channel, grouped by the
/// graph it is drawn on, and *Markers* with the depth plot whose baseline they stand on —
/// a switch, but not a channel.
struct ProfileChannelMenu: View {
  let chart: ProfileChart
  @Binding var hidden: Set<ProfileChannel>
  @Binding var markersHidden: Bool

  var body: some View {
    Menu {
      ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
        Section {
          ForEach(group, id: \.self) { channel in
            Toggle(isOn: shown(channel)) {
              Text(channel.label + " (" + channel.display(chart.units).unit + ")")
            }
          }
          if index == 0 && !chart.events.isEmpty {
            Toggle("Markers", isOn: $markersHidden.not)
          }
        }
      }
    } label: {
      Image(systemName: "slider.horizontal.3")
        .frame(minWidth: 44, minHeight: 44)
    }
    .menuActionDismissBehavior(.disabled)
    .accessibilityLabel(chart.events.isEmpty ? "Channels" : "Channels and markers")
  }

  /// The depth plot's channels first, then each row's under it.
  private var groups: [[ProfileChannel]] {
    let available = chart.availableChannels
    return
      ([available.filter { !ProfileAxis.panels.contains($0.axis) }]
      + ProfileAxis.panels.map { axis in available.filter { $0.axis == axis } })
      .enumerated()
      .filter { $0.offset == 0 || !$0.element.isEmpty }
      .map(\.element)
  }

  private func shown(_ channel: ProfileChannel) -> Binding<Bool> {
    Binding {
      !hidden.contains(channel)
    } set: { on in
      if on { hidden.remove(channel) } else { hidden.insert(channel) }
    }
  }
}

extension Binding where Value == Bool {
  fileprivate var not: Binding<Bool> {
    Binding {
      !wrappedValue
    } set: {
      wrappedValue = !$0
    }
  }
}

#Preview {
  @Previewable @State var hidden: Set<ProfileChannel> = [.ceiling]
  @Previewable @State var markersHidden = false
  ProfileChannelMenu(chart: .preview, hidden: $hidden, markersHidden: $markersHidden)
}
