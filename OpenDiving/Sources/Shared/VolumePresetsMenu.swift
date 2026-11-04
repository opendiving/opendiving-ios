import OpenDivingKit
import SwiftUI

/// The presets beside a cylinder's volume, in a dive's tank and a gear item alike: the diver's
/// recent volumes, then the families.
struct VolumePresetsMenu: View {
  let groups: [VolumePresetGroup]
  let units: UnitSystem
  let onPick: (Double) -> Void

  var body: some View {
    Menu {
      ForEach(groups, id: \.title) { group in
        Section(group.title) {
          ForEach(group.presets, id: \.self) { preset in
            Button(preset.label(units)) { onPick(preset.liters) }
          }
        }
      }
    } label: {
      Image(systemName: "chevron.down.circle")
    }
    .buttonStyle(.borderless)
    .accessibilityLabel("Volume presets")
  }
}

#Preview {
  Form {
    VolumePresetsMenu(groups: [], units: .metric) { _ in }
  }
}
