import Foundation

/// An address of a page the app has a screen for, read into the server it names and what it
/// opens. Only the path and the `token` query item are read: any other query item, a fragment and
/// one trailing slash are ignored, and a uuid is read in either case. Its tokens are credentials,
/// and nothing writes one down.
public struct AppLink: Hashable, Sendable {
  public enum Target: Hashable, Sendable {
    /// `/connect/<token>`.
    case connect(token: String)
    /// `/auth/verify?token=<token>`.
    case signIn(token: String)
    case record(Record)
  }

  /// A record page, `/<directory>/<uuid>`.
  public enum Record: Hashable, Sendable {
    case site(UUID)
    case dive(UUID)
    case trip(UUID)
    case person(UUID)
    case gearItem(UUID)
    case course(UUID)
    case species(UUID)
    case importPage(UUID)
  }

  /// What a link the app acts on opens: a record's screen or a connect link's.
  public enum Screen: Hashable, Sendable {
    case record(Record)
    case connect(token: String)
  }

  public let origin: ServerOrigin
  public let target: Target

  public init(origin: ServerOrigin, target: Target) {
    self.origin = origin
    self.target = target
  }

  /// Nil for anything that is not an `http` or `https` address of one of those pages.
  public init?(_ url: URL) {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https",
      let origin = ServerOrigin(url.absoluteString)
    else { return nil }
    var path = components.percentEncodedPath
    if path.count > 1, path.hasSuffix("/") { path.removeLast() }
    let parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    guard parts.count == 3, parts[0].isEmpty else { return nil }
    let target: Target
    switch (parts[1], parts[2]) {
    case ("auth", "verify"):
      guard
        let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
        !token.isEmpty
      else { return nil }
      target = .signIn(token: token)
    case ("connect", let token):
      guard Self.isConnectToken(token) else { return nil }
      target = .connect(token: token)
    case (let directory, let value):
      guard let uuid = UUID(uuidString: value), let record = Self.record(directory, uuid)
      else { return nil }
      target = .record(record)
    }
    self.init(origin: origin, target: target)
  }

  /// What was scanned or pasted, as an address once trimmed, whether or not it is a link the app
  /// opens. Nil for text that names no scheme.
  public static func url(given text: String) -> URL? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let url = URL(string: trimmed), url.scheme != nil else { return nil }
    return url
  }

  /// The pattern the API holds a `via` to, which a connect link's token is made to fit: 1 to 32
  /// lowercase letters, digits and hyphens.
  static func isConnectToken(_ token: String) -> Bool {
    (1...32).contains(token.count)
      && token.unicodeScalars.allSatisfy { scalar in
        ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) || scalar == "-"
      }
  }

  private static func record(_ directory: String, _ uuid: UUID) -> Record? {
    switch directory {
    case "sites": .site(uuid)
    case "dives": .dive(uuid)
    case "trips": .trip(uuid)
    case "people": .person(uuid)
    case "gear": .gearItem(uuid)
    case "courses": .course(uuid)
    case "species": .species(uuid)
    case "import": .importPage(uuid)
    default: nil
    }
  }
}
