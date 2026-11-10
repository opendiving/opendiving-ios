/// The three groups of the check-in details, each edited and saved alone: a save sends its
/// group's members and no other, so a stale copy of the screen cannot revert another group.
public enum CheckinGroup: String, CaseIterable, Hashable, Sendable, Identifiable {
  case about
  case insurance
  case emergency

  public var id: Self { self }

  public var title: String {
    switch self {
    case .about: "About You"
    case .insurance: "Dive Insurance"
    case .emergency: "Emergency Contacts"
    }
  }

  public var description: String {
    switch self {
    case .about: "Your own details, as a desk asks for them."
    case .insurance:
      "Each policy a shop takes down: the provider, the policy number, and when the cover runs"
        + " out."
    case .emergency:
      "Who a shop calls if something goes wrong, and how they know you. The first is called"
        + " first."
    }
  }

  /// Under the group once its save has landed.
  public var savedMessage: String {
    switch self {
    case .about: "Your details are up to date."
    case .insurance: "Your insurance policies are up to date."
    case .emergency: "Your emergency contacts are up to date."
    }
  }
}
