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

extension GearItemFormValues: RewritesLocalRefs {
  /// An item names no other record.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {}
}
