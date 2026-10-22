/// The lines a recording's row says about the computer that made it.
///
/// A recording's mode, decompression algorithm and salinity have **no fallback**: a value
/// this build does not know is left unsaid rather than printed raw, and an absent mode
/// is never open circuit.
public enum RecordingLabels {
  /// What to call a recording whose source named no computer at all.
  public static let unnamedDevice = "Dive computer"

  /// The device on one line — brand and model, then the serial, then the name its owner
  /// gave it — or nil when it carries nothing to identify it. A model already starting
  /// with its brand does not get the brand twice, and a name equal to the model is
  /// dropped.
  public static func device(brand: String?, model: String?, serial: String?, name: String?)
    -> String?
  {
    let brand = nonBlank(brand)
    let model = nonBlank(model)
    let serial = nonBlank(serial)
    let name = nonBlank(name)

    var machineParts: [String] = []
    if let brand, !(model?.lowercased().hasPrefix(brand.lowercased()) ?? false) {
      machineParts.append(brand)
    }
    if let model { machineParts.append(model) }
    let machine = machineParts.joined(separator: " ")

    var label = [machine, serial ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    if let name, name.lowercased() != model?.lowercased() {
      label = label.isEmpty ? name : "\(label) (\(name))"
    }
    return label.isEmpty ? nil : label
  }

  /// What the device was set to — `Open circuit · Bühlmann GF 30/85 · salinity EN13319`
  /// — or nil where the source recorded none of it. The deco model's own name wins over
  /// its family's; the gradient factors attach to it only as a pair; a conservatism of
  /// 0 is a setting, and a positive one keeps its sign.
  public static func settings(
    mode: String?, decoName: String?, decoAlgorithm: String?, gfLow: Int?, gfHigh: Int?,
    conservatism: Int?, salinity: String?
  ) -> String? {
    var deco: [String] = []
    if let named = nonBlank(decoName) ?? decoAlgorithm.flatMap({ algorithms[$0] }) {
      deco.append(named)
    }
    if let gfLow, let gfHigh { deco.append("GF \(gfLow)/\(gfHigh)") }

    var model: [String] = []
    if !deco.isEmpty { model.append(deco.joined(separator: " ")) }
    if let conservatism {
      model.append("conservatism " + (conservatism > 0 ? "+\(conservatism)" : "\(conservatism)"))
    }

    var parts: [String] = []
    if let label = mode.flatMap({ modes[$0] }) { parts.append(label) }
    if !model.isEmpty { parts.append(model.joined(separator: " · ")) }
    if let label = salinity.flatMap({ salinities[$0] }) { parts.append("salinity " + label) }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  /// The device's own readouts for the dive — `CNS 0% → 9% · OTU 0 → 22 · Surface
  /// pressure 1.012 bar` — each as stored, a missing half as an em dash; nil where it
  /// reported none.
  public static func readouts(
    cnsStart: Double?, cnsEnd: Double?, otuStart: Double?, otuEnd: Double?,
    surfacePressureBar: Double?
  ) -> String? {
    func pair(_ label: String, _ start: Double?, _ end: Double?, _ unit: String = "")
      -> String?
    {
      guard start != nil || end != nil else { return nil }
      let side = { (value: Double?) in value.map { NumberText.plain($0) + unit } ?? "—" }
      return "\(label) \(side(start)) → \(side(end))"
    }
    let parts = [
      pair("CNS", cnsStart, cnsEnd, "%"),
      pair("OTU", otuStart, otuEnd),
      surfacePressureBar.map { "Surface pressure \(NumberText.plain($0)) bar" },
    ].compactMap { $0 }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  static let modes = [
    "open_circuit": "Open circuit", "closed_circuit": "Closed circuit",
    "semi_closed": "Semi-closed", "gauge": "Gauge", "freedive": "Freedive",
  ]

  static let algorithms = ["buhlmann": "Bühlmann", "rgbm": "RGBM"]

  static let salinities = ["fresh": "Fresh", "en13319": "EN13319", "salt": "Salt"]

  private static func nonBlank(_ value: String?) -> String? {
    let trimmed = value?.trimmedOfWhitespace ?? ""
    return trimmed.isEmpty ? nil : trimmed
  }
}
