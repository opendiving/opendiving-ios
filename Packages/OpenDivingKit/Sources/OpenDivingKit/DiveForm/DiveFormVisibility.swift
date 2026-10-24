/// Which of the dive form's fields one form shows, by the rule the web states: a field is
/// visible unless the account hides it, and a hidden field is shown on this form when a value
/// arrived in it from outside the diver's typing — the dive being edited, a restored draft, a
/// gear set loaded into it. For the same account and the same dive the phone shows what the web
/// shows. The hidden set is the account's, edited on the web and read here, never written.
public struct DiveFormVisibility: Hashable, Sendable {
  /// The account's hidden set, in form order.
  public let hidden: [DiveFormField]
  /// Hidden fields this form shows anyway, because a value arrived in them.
  public private(set) var revealed: Set<DiveFormField> = []

  /// `hiddenKeys` as `GET /user` names them, or as ``AccountFormSettings`` kept them.
  public init(hiddenKeys: [String]) {
    hidden = DiveFormField.canonical(hiddenKeys)
  }

  /// In the account's set, revealed or not.
  public func isHidden(_ field: DiveFormField) -> Bool { hidden.contains(field) }

  /// Shown here only because a value arrived in it.
  public func isRevealed(_ field: DiveFormField) -> Bool { revealed.contains(field) }

  /// Not hidden, or hidden and revealed. *Import* is never visible on the phone.
  public func isVisible(_ field: DiveFormField) -> Bool {
    guard field != .fileImport else { return false }
    return !hidden.contains(field) || revealed.contains(field)
  }

  /// Whether the form draws the field for these values: visible, and for the boat name also
  /// offered — on a boat entry, or while it holds a name, so a name is never kept out of reach.
  public func shows(_ field: DiveFormField, in values: DiveFormValues) -> Bool {
    guard isVisible(field) else { return false }
    if field == .boatName { return values.entryType == "boat" || !values.boatName.isEmpty }
    return true
  }

  /// Puts these fields on this form, the stored set untouched.
  public mutating func reveal(_ fields: some Sequence<DiveFormField>) {
    revealed.formUnion(fields.filter { hidden.contains($0) })
  }

  /// Reveals every field `values` holds something in: how an edit's dive, a restored draft or
  /// a failed item's payload arrives.
  public mutating func reveal(holdingValuesIn values: DiveFormValues) {
    reveal(values.nonEmptyFields)
  }

  /// Reveals the fields a failed save has sentences for, so no message is left on a field the
  /// diver cannot see; a tank's sentence reveals the tanks as well as its column.
  public mutating func reveal(failing invalid: FormInvalid) {
    var fields: [DiveFormField] = []
    for issue in invalid.issues {
      if issue.field == DiveFormField.mixtures.rawValue {
        fields.append(.mixtures)
        if let member = issue.member, let column = DiveFormField(rawValue: "mixture." + member) {
          fields.append(column)
        }
      } else if let field = DiveFormField(rawValue: issue.field) {
        fields.append(field)
      }
    }
    reveal(fields)
  }

  /// `values` with every field this form does not show emptied — on every tank for a column —
  /// which is what a new dive carries into a hidden field: nothing, until the diver shows it.
  public func applied(to values: DiveFormValues) -> DiveFormValues {
    var result = values
    for field in DiveFormField.allCases where field.holdsValue && !isVisible(field) {
      result.clear(field)
    }
    return result
  }
}
