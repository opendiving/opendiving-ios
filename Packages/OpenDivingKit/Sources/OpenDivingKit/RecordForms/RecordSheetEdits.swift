/// What the record sheets' controls do to the values, beyond setting a field.
extension DiveSiteFormValues {
  /// A tag, as typed, unless the site has it already in any case — the dive form's rule.
  public mutating func addTag(_ text: String) {
    let tag = text.trimmedOfWhitespace
    guard !tag.isEmpty, !tags.contains(where: { $0.lowercased() == tag.lowercased() }) else {
      return
    }
    tags.append(tag)
  }

  public mutating func removeTag(_ tag: String) { tags.removeAll { $0 == tag } }

  /// Ticks or unticks an entry type, keeping the order they were ticked in.
  public mutating func setEntryType(_ entry: String, _ on: Bool) {
    entryTypes.set(entry, on)
  }

  /// The altitude as a measured box edits it: metres, kept whole as the column holds them. A
  /// number past Int's range is held at a billion metres either way rather than converted, which
  /// would trap; the form's band refuses it with its sentence.
  public var altitudeMeters: Double? {
    get { altitude.map(Double.init) }
    set { altitude = newValue.map { Int(min(max($0.rounded(), -1e9), 1e9)) } }
  }
}

extension ContactFormValues {
  /// Ticks or unticks a role, keeping the order they were ticked in.
  public mutating func setRole(_ role: String, _ on: Bool) {
    roles.set(role, on)
  }
}

extension GearItemFormValues {
  /// A cylinder's facts go with the cylinder: changed to another type, its volume, working
  /// pressure and material are dropped, so a figure left in a box no longer shown cannot hold
  /// the save back.
  public mutating func setType(_ type: String?) {
    self.type = type
    guard !isCylinder else { return }
    volume = nil
    workingPressure = nil
    material = nil
    presetWorkingPressure = nil
    presetMaterial = nil
  }

  /// A Volume preset: its litres, and the rating and material a named cylinder pins down, each
  /// where it is empty or still what an earlier pick wrote — what the diver set is this cylinder,
  /// not the catalogue's, while a mistaken AL80 picked over leaves nothing of itself behind.
  public mutating func pickVolume(_ preset: VolumePreset) {
    volume = preset.liters
    if workingPressure == nil || workingPressure == presetWorkingPressure {
      workingPressure = preset.workingPressure
      presetWorkingPressure = preset.workingPressure
    } else {
      presetWorkingPressure = nil
    }
    if material == nil || material == presetMaterial {
      material = preset.material
      presetMaterial = preset.material
    } else {
      presetMaterial = nil
    }
  }
}

extension GearSetSaveValues {
  /// *Save to*: an existing set lends its name, which the diver may still change; a new set
  /// starts unnamed (`handleTargetChange`).
  public mutating func pickTarget(_ ref: RecordRef?, among sets: [GearSetRow]) {
    target = ref
    form.name = ref.flatMap { ref in sets.first { $0.ref == ref }?.name } ?? ""
  }
}

extension Array where Element == String {
  fileprivate mutating func set(_ key: String, _ on: Bool) {
    if on {
      if !contains(key) { append(key) }
    } else {
      removeAll { $0 == key }
    }
  }
}
