/// `POST /dive-site/{uuid}/proposals`'s body. The diver's own site is proposed as it stands and
/// sends no `members`; a change to a Commons record sends what it wants different.
public struct DiveSiteProposalCreate: Codable, Hashable, Sendable {
  /// The words the diver ticked, exactly: ``CommonsAttestations``.
  public var attestation: String
  /// An optional word for the reviewer.
  public var message: String
  public var members: DiveSiteMembersChange?
  /// Whether other divers read the diver's name beside it in the site's history. Sent only when
  /// on, so a proposal without it has the body it always had.
  public var showProposer: Bool

  public init(
    attestation: String, message: String = "", members: DiveSiteMembersChange? = nil,
    showProposer: Bool = false
  ) {
    self.attestation = attestation
    self.message = message
    self.members = members
    self.showProposer = showProposer
  }

  private enum CodingKeys: String, CodingKey {
    case attestation, message, members, showProposer
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    attestation = try c.decode(String.self, forKey: .attestation)
    message = try c.decode(String.self, forKey: .message)
    members = try c.decodeIfPresent(DiveSiteMembersChange.self, forKey: .members)
    showProposer = try c.decodeIfPresent(Bool.self, forKey: .showProposer) ?? false
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(attestation, forKey: .attestation)
    try c.encode(message, forKey: .message)
    try c.encodeIfPresent(members, forKey: .members)
    if showProposer { try c.encode(true, forKey: .showProposer) }
  }
}
