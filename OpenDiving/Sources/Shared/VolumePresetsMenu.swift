import OpenDivingKit
import SwiftUI

/// The presets beside a cylinder's volume, in a dive's tank and a gear item alike: the diver's
/// recent volumes, then the families. A tank takes a pick's litres alone; a gear item its rating
/// and material too.
struct VolumePresetsMenu: View {
  let groups: [VolumePresetGroup]
  let units: UnitSystem
  let onPick: (VolumePreset) -> Void

  var body: some View {
    Menu {
      ForEach(groups, id: \.title) { group in
        Section(group.title) {
          ForEach(group.presets, id: \.self) { preset in
            Button(preset.label(units)) { onPick(preset) }
          }
        }
      }
    } label: {
      Image(systemName: "chevron.down.circle").accentRow()
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
