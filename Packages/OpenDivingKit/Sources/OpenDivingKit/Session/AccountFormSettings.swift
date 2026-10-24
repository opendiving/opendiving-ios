/// The two values of an account the dive form reads, kept in the account's directory when the
/// account loads so that a signed-out form still writes in the diver's units and hides what
/// the diver hid. The rest of the account goes at sign-out.
public struct AccountFormSettings: Codable, Hashable, Sendable {
  public let units: UnitSystem
  /// `UserRead.diveFormHiddenFields`, as last read.
  public let diveFormHiddenFields: [String]

  public init(units: UnitSystem, diveFormHiddenFields: [String]) {
    self.units = units
    self.diveFormHiddenFields = diveFormHiddenFields
  }
}
