import OpenDivingKit
import SwiftUI

/// The *Tanks* section: a *Tank n* card per cylinder, each removable, *Add tank* under them —
/// where the next one appears — and the depth warning under the list.
struct TanksSection: View {
  let model: DiveFormModel

  var body: some View {
    ForEach(model.values.tanks.indices, id: \.self) { index in
      TankCard(model: model, index: index)
    }
    if model.values.tanks.isEmpty {
      Text("No tanks recorded for this dive.")
        .foregroundStyle(.secondary)
    }
    Button("Add tank", systemImage: "plus") { model.addTank() }
    if let warning = model.modWarning {
      Label(warning, systemImage: "exclamationmark.triangle")
        .font(.footnote)
        .foregroundStyle(.orange)
    }
  }
}

/// One cylinder: linked to the diver's gear or not, its volume, mix, limit, pressures, usage and
/// role — each column where the account shows it — and the gas hint under it.
private struct TankCard: View {
  let model: DiveFormModel
  let index: Int

  var body: some View {
    if model.values.tanks.indices.contains(index) {
      card(model.values.tanks[index])
    }
  }

  private func card(_ tank: TankValues) -> some View {
    let visibility = model.visibility
    return VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Tank \(index + 1)").font(.headline)
        Spacer()
        Button(role: .destructive) {
          model.removeTank(index)
        } label: {
          Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Remove tank \(index + 1)")
      }
      if visibility.isVisible(.mixtureCylinder) {
        RecordPickerField(
          model: model, title: DiveFormField.mixtureCylinder.label, picker: .cylinder,
          tank: index, value: tank.cylinder
        ) { model.linkCylinder($0, tank: index) }
      }
      VolumeField(
        model: model, value: tank.shownVolume, isReadOnly: tank.isVolumeFromVessel,
        error: message("volume")
      ) { volume in model.changeTank(index) { $0.volume = volume } }
      if visibility.isVisible(.mixturePo2Limit) {
        Picker(
          "ppO₂ limit (bar)",
          selection: Binding(
            get: { tank.po2Limit },
            set: { limit in model.changeTank(index) { $0.po2Limit = limit } })
        ) {
          Text("Not recorded (\(NumberText.plain(GasMath.workingPPO2)) default)")
            .tag(Double?.none)
          ForEach(DiveFormModel.po2LimitChoices(tank.po2Limit), id: \.self) { limit in
            Text(NumberText.fixed(limit, decimals: 1)).tag(Double?.some(limit))
          }
        }
        if let error = message("po2_limit") { FieldMessage(error) }
      }
      DecimalField(title: "O₂ (%)", value: tank.oxygen, error: message("oxygen")) { oxygen in
        model.changeTank(index) { $0.oxygen = oxygen }
      }
      if visibility.isVisible(.mixtureHelium) {
        DecimalField(title: "He (%)", value: tank.helium, error: message("helium")) { helium in
          model.changeTank(index) { $0.helium = helium }
        }
      }
      if visibility.isVisible(.mixtureStartPressure) {
        MeasuredField(
          model: model, title: "Start pressure", measure: .pressure, min: 0,
          value: tank.startPressure, error: message("start_pressure")
        ) { bar in model.changeTank(index) { $0.startPressure = bar } }
      }
      if visibility.isVisible(.mixtureEndPressure) {
        MeasuredField(
          model: model, title: "End pressure", measure: .pressure, min: 0,
          value: tank.endPressure, error: message("end_pressure")
        ) { bar in model.changeTank(index) { $0.endPressure = bar } }
      }
      if visibility.isVisible(.mixtureUsage) {
        VocabularyPicker(
          title: DiveFormField.mixtureUsage.label, values: FormVocabulary.tankUsages,
          label: Self.usageLabel, selection: tank.usage
        ) { usage in model.changeTank(index) { $0.usage = usage } }
      }
      if visibility.isVisible(.mixtureRole) {
        VocabularyPicker(
          title: DiveFormField.mixtureRole.label, values: FormVocabulary.gasRoles,
          label: VocabularyLabels.gasRole, selection: tank.role
        ) { role in model.changeTank(index) { $0.role = role } }
      }
      if let hint = model.tankHint(index) {
        Text(hint).font(.footnote).foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)
  }

  private func message(_ member: String) -> String? {
    model.message("mixtures", index: index, member: member)
  }

  /// The menu's own wording, which says what each means for the set.
  private static func usageLabel(_ usage: String) -> String {
    switch usage {
    case "parallel": "Parallel (sidemount / independent)"
    case "staged": "Staged (own depth)"
    default: VocabularyLabels.tankUsage(usage)
    }
  }
}

/// A tank's volume in litres, in both unit systems: typed, or picked from the presets — the
/// diver's recent volumes, then the families, theirs first. Read-only while a linked cylinder
/// records its capacity.
private struct VolumeField: View {
  let model: DiveFormModel
  let value: Double?
  let isReadOnly: Bool
  var error: String?
  let onChange: (Double?) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .bottom) {
        DecimalField(title: "Volume (L)", value: value, isReadOnly: isReadOnly, onChange: onChange)
        if !isReadOnly {
          Menu {
            ForEach(model.volumeGroups, id: \.title) { group in
              Section(group.title) {
                ForEach(group.presets, id: \.label) { preset in
                  Button(preset.label(model.units)) { onChange(preset.liters) }
                }
              }
            }
          } label: {
            Image(systemName: "chevron.down.circle")
          }
          .accessibilityLabel("Volume presets")
        }
      }
      if let error { FieldMessage(error) }
    }
  }
}

#Preview {
  Form {
    TanksSection(model: DiveFormModel(session: DivePreviewData.session, mode: .create))
  }
}
