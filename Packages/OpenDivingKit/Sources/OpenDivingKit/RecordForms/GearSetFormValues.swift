/// The gear set dialog's values and rules (`gearSetSchema`), which the dive form's *Save as set*
/// opens over the dive's gear and weight to create a set or replace one.
public struct GearSetFormValues: Codable, Hashable, Sendable {
  public var name: String
  /// Kilograms; nil is no default weight.
  public var weight: Double?
  /// In the set's order.
  public var items: [RecordRef]

  public init(name: String = "", weight: Double? = nil, items: [RecordRef] = []) {
    self.name = name
    self.weight = weight
    self.items = items
  }

  /// *Save as set* over a dive's form: its gear and its weight.
  public init(saving values: DiveFormValues) {
    self.init(weight: values.weight, items: values.gearItems)
  }

  public var issues: [FormIssue] {
    var list = FormIssueList()
    list.add("name", FormText.requiredName(name, "Set name", max: 255))
    if let weight, weight < 0 { list.add("weight", "Weight must be zero or positive") }
    return list.issues
  }

  /// `POST /gear-set`'s body.
  public func toCreate() throws(FormInvalid) -> GearSetCreate {
    if !issues.isEmpty { throw FormInvalid(issues: issues) }
    return GearSetCreate(name: name.trimmedOfWhitespace, weight: weight, gearItems: items)
  }

  /// `PATCH /gear-set/{uuid}`'s body for a set this replaces: the whole list and the weight,
  /// a cleared weight sent as `null`.
  public func toUpdate() throws(FormInvalid) -> GearSetUpdate {
    if !issues.isEmpty { throw FormInvalid(issues: issues) }
    return GearSetUpdate(
      name: name.trimmedOfWhitespace, weight: weight.map(Patch.value) ?? .null, gearItems: items)
  }
}

extension GearSetFormValues: RewritesLocalRefs {
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    items.rewrite(rewrite)
  }
}
