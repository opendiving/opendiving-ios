import Foundation

/// The server a phone talks to, as an origin: scheme, host and port, nothing else. Everything
/// kept per server — the refresh token, the remembered account, the cached sheet, and each
/// account's drafts, writes waiting to sync, files waiting to be read, dive computers
/// downloaded from and copies of the logbook — is keyed by it, scheme included, so `http://`
/// and `https://` on one host are two servers.
public struct ServerOrigin: Hashable, Sendable, Codable, CustomStringConvertible {
  /// `http` or `https`.
  public let scheme: String
  /// Lowercased.
  public let host: String
  /// Nil for the scheme's default port.
  public let port: Int?

  /// Reads whatever the user typed down to its origin: `https://opendiving.app/dives` is
  /// `https://opendiving.app`, and a bare host gets `https://`. Nil when no http or https
  /// host can be read out of it.
  public init?(_ input: String) {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let hasScheme = trimmed.contains("://")
    guard let components = URLComponents(string: hasScheme ? trimmed : "https://" + trimmed),
      // `mailto:diver@example.com` with `https://` put in front reads as a user and a host.
      hasScheme || components.user == nil,
      let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https",
      var host = components.host?.lowercased(), !host.isEmpty
    else { return nil }
    if host.hasPrefix("["), host.hasSuffix("]") {
      host = String(host.dropFirst().dropLast())
    }
    let defaultPort = scheme == "https" ? 443 : 80
    self.scheme = scheme
    self.host = host
    self.port = components.port.flatMap { $0 == defaultPort ? nil : $0 }
  }

  /// `scheme://host[:port]`, the form ``init(_:)`` reads back to the same origin.
  public var description: String {
    let hostPart = host.contains(":") ? "[\(host)]" : host
    return "\(scheme)://\(hostPart)" + (port.map { ":\($0)" } ?? "")
  }

  /// The origin as a URL with no path.
  public var url: URL {
    // A value built by `init?(_:)` always forms a URL.
    URL(string: description)!
  }

  /// `{origin}/api/v1`, which the API mounts at a fixed prefix.
  public var apiBaseURL: URL {
    url.appendingPathComponent("api").appendingPathComponent("v1")
  }

  /// The origin as one path component, for the per-server directory.
  public var slug: String {
    let raw = "\(scheme)-\(host)" + (port.map { "-\($0)" } ?? "")
    return String(
      raw.unicodeScalars.map { scalar in
        CharacterSet.alphanumerics.contains(scalar) || scalar == "." || scalar == "-"
          ? Character(scalar) : "_"
      })
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let text = try container.decode(String.self)
    guard let origin = ServerOrigin(text) else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Not a server origin: \"\(text)\"")
    }
    self = origin
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(description)
  }
}
