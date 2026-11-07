/// `POST /dive-site/{uuid}/proposals`'s body. The diver's own site is proposed as it stands and
/// sends no `members`; a change to a Commons record sends what it wants different.
public struct DiveSiteProposalCreate: Codable, Hashable, Sendable {
  /// The words the diver ticked, exactly: ``CommonsAttestations``.
  public var attestation: String
  /// An optional word for the reviewer.
  public var message: String
  public var members: DiveSiteMembersChange?

  public init(attestation: String, message: String = "", members: DiveSiteMembersChange? = nil) {
    self.attestation = attestation
    self.message = message
    self.members = members
  }
}
