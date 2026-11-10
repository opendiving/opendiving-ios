import Observation

/// *Preferences*: the account's units, saved on change, and its tags.
@MainActor
@Observable
public final class PreferencesModel {
  public let write: AccountWrite
  public let tags: TagsModel
  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    write = AccountWrite(session: session)
    tags = TagsModel(session: session)
  }

  /// The units as the account has them, or as the diver just chose them.
  public var units: UnitSystem { write.shown?.units ?? session.units }

  public func setUnits(_ units: UnitSystem) async {
    guard units != self.units else { return }
    await write.save(UserUpdate(units: units))
  }
}
