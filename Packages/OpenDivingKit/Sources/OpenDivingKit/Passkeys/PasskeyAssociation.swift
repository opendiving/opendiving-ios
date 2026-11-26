import Foundation

/// What the build brings to a passkey: the one host its associated domain names, and the
/// system's ceremony. The system refuses a ceremony for any other relying party, so a passkey
/// is offered on that host's server alone.
@MainActor
public struct PasskeyAssociation {
  public let host: String
  public let ceremony: any PasskeyCeremony

  /// Nil where the build names no host: the association is off.
  public init?(domain: String?, ceremony: any PasskeyCeremony) {
    guard let host = Self.host(domain) else { return nil }
    self.host = host
    self.ceremony = ceremony
  }

  /// The host of the build's domain line, `opendiving.app?mode=developer` read as
  /// `opendiving.app`; nil for no line or an empty one.
  nonisolated public static func host(_ domain: String?) -> String? {
    guard let domain else { return nil }
    let host =
      domain.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
      .first.map(String.init)?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
    return host.isEmpty ? nil : host
  }

  /// Whether a passkey is offered: where the build's host is the host of the server the app is
  /// on, whatever its scheme and port, and nowhere else.
  public static func isOffered(buildHost: String?, on state: Session.State) -> Bool {
    guard let buildHost, let origin = state.origin else { return false }
    return origin.host.lowercased() == buildHost.lowercased()
  }
}
