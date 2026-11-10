/// The *New Gear* dialog's values and rules (`gearItemSchema`). A cylinder's facts — its
/// volume, working pressure and material — are shown and sent only for a cylinder.
public struct GearItemFormValues: Codable, Hashable, Sendable {
  public var name: String
  public var brand: String
  /// A gear-type key; nil is no type.
  public var type: String?
  public var notes: String
  public var rented: Bool
  /// Litres of water capacity.
  public var volume: Double?
  /// Bar.
  public var workingPressure: Double?
  public var material: String?
  /// What the last Volume preset wrote into each, which the next pick may replace; a figure the
  /// diver set since no longer matches and stays.
  var presetWorkingPressure: Double?
  var presetMaterial: String?

  /// `type` is the host's preset — a tank's cylinder picker opens the dialog as a cylinder —
  /// and `name` what was typed into the picker before *Add*.
  public init(
    name: String = "", brand: String = "", type: String? = nil, notes: String = "",
    rented: Bool = false, volume: Double? = nil, workingPressure: Double? = nil,
    material: String? = nil
  ) {
    self.name = name
    self.brand = brand
    self.type = type
    self.notes = notes
    self.rented = rented
    self.volume = volume
    self.workingPressure = workingPressure
    self.material = material
  }

  /// Whether the cylinder's facts are on screen.
  public var isCylinder: Bool { type == "cylinder" }

  public var issues: [FormIssue] {
    var list = FormIssueList()
    list.add("name", FormText.requiredName(name, "Gear name", max: 255))
    list.add("brand", FormText.length(brand, "Brand", max: 255))
    list.add("notes", FormText.length(notes, "Notes", max: DiveFormBounds.notesMax))
    if let volume, volume <= 0 { list.add("volume", "Volume must be positive") }
    if let workingPressure {
      if workingPressure <= 0 {
        list.add("working_pressure", "Working pressure must be positive")
      } else if workingPressure > DiveFormBounds.maxPressureBar {
        list.add("working_pressure", "Working pressure " + DiveFormValues.pressureCeilingClause)
      }
    }
    return list.issues
  }

  /// `POST /gear-item`'s body: the name and brand trimmed, a cylinder's facts only for a
  /// cylinder (`vesselFactsToSave`).
  public func toCreate() throws(FormInvalid) -> GearItemCreate {
    if !issues.isEmpty { throw FormInvalid(issues: issues) }
    return GearItemCreate(
      name: name.trimmedOfWhitespace, brand: FormText.trimmedOrNil(brand), type: type,
      notes: notes, rented: rented, volume: isCylinder ? volume : nil,
      workingPressure: isCylinder ? workingPressure : nil, material: isCylinder ? material : nil)
  }
}

extension GearItemFormValues {
  /// The form an edit opens on.
  public init(editing item: GearItemRead) {
    self.init(
      name: item.name, brand: item.brand ?? "", type: item.type, notes: item.notes,
      rented: item.rented, volume: item.volume, workingPressure: item.workingPressure,
      material: item.material)
  }

  /// `PATCH /gear-item/{uuid}`'s body: what differs from the values the form opened on. An item
  /// that is no longer a cylinder has its cylinder's facts cleared.
  public func diff(from baseline: GearItemFormValues) throws(FormInvalid) -> GearItemUpdate {
    let now = try toCreate()
    var update = GearItemUpdate()
    if now.name != baseline.name.trimmedOfWhitespace { update.name = now.name }
    if now.notes != baseline.notes { update.notes = now.notes }
    if now.rented != baseline.rented { update.rented = now.rented }
    update.brand = .change(from: FormText.trimmedOrNil(baseline.brand), to: now.brand)
    update.type = .change(from: baseline.type, to: now.type)
    update.volume = .change(from: baseline.volume, to: now.volume)
    update.workingPressure = .change(from: baseline.workingPressure, to: now.workingPressure)
    update.material = .change(from: baseline.material, to: now.material)
    return update
  }

  /// These values with a queued update laid over; an archive changes nothing on the form.
  public func applying(_ update: GearItemUpdate) -> GearItemFormValues {
    var next = self
    if let name = update.name { next.name = name }
    if let notes = update.notes { next.notes = notes }
    if let rented = update.rented { next.rented = rented }
    next.brand = update.brand.applied(to: brand) ?? ""
    next.type = update.type.applied(to: type)
    next.volume = update.volume.applied(to: volume)
    next.workingPressure = update.workingPressure.applied(to: workingPressure)
    next.material = update.material.applied(to: material)
    return next
  }
}

extension GearItemFormValues: RewritesLocalRefs {
  /// An item names no other record.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {}
}
