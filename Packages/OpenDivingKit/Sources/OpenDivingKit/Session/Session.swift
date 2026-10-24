import Foundation
import Observation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The app's one session: which server it is pointed at, whether it is signed in there, the
/// account and the people table. The root injects one; every view reads it from the
/// environment and none constructs its own.
///
/// A cold start is derived from the active-origin pointer and the ``SecretStore`` alone: no
/// pointer is ``State/noServer``, a pointer with no refresh token ``State/signingIn(_:)``, and
/// a pointer with one ``State/signedIn(_:)`` — which then wants ``resume()``.
@MainActor
@Observable
public final class Session {
  public enum State: Hashable, Sendable {
    case noServer
    case signingIn(ServerOrigin)
    case signedIn(ServerOrigin)

    public var origin: ServerOrigin? {
      switch self {
      case .noServer: nil
      case .signingIn(let origin), .signedIn(let origin): origin
      }
    }
  }

  /// What redeeming a code led to. Only ``signedIn`` started a session; the other two are
  /// finished on the web.
  public enum SignInOutcome: Hashable, Sendable {
    case signedIn
    case onboardingRequired(email: String?, name: String?)
    case deletionPending(email: String?, purgeAfter: DiveTimestamp?)
  }

  public private(set) var state: State
  /// Whether ``loadAccount()`` has read the account in this session since ``state`` last
  /// changed, whichever caller ran it. Until it has, a signed-in session does not know which
  /// account its token is — a sign-in's answer names none — so the last-account pointer and
  /// the account's directory may still be the previous account's, and nothing that writes to
  /// the server on an account's behalf should run.
  public private(set) var accountLoaded = false
  /// The account, as last read from the server or remembered from the last time it was.
  public private(set) var user: UserRead? = nil
  /// Everyone a dive, a trip, a course or a card can name, by uuid.
  public private(set) var people: [UUID: PersonRead] = [:]
  /// The active server as it last answered ``validate(_:)``.
  public private(set) var server: ServerInfo? = nil
  /// The active server's client; nil with no server.
  public private(set) var client: APIClient? = nil

  /// The account's units; metric until the account is known.
  public var units: UnitSystem { user?.units ?? .metric }

  @ObservationIgnored private let transport: any HTTPTransport
  @ObservationIgnored private let secrets: any SecretStore
  @ObservationIgnored private let activeOrigin: any ActiveOriginStore
  @ObservationIgnored private let userAgent: UserAgent
  @ObservationIgnored public let store: ServerStateStore
  /// Keeps the app running while work that must not be cut off finishes: a token rotating, a
  /// queue flushing.
  @ObservationIgnored public nonisolated let background: any BackgroundExecution
  /// Whether a route is believed to exist, and the moments worth trying again.
  @ObservationIgnored public nonisolated let connectivity: any Connectivity
  /// Bumped on every change of ``state``, so a load that began before one cannot land after it.
  @ObservationIgnored private var stateGeneration = 0

  /// The device's session. `configuration` is the app target's, carrying what Linux's
  /// Foundation cannot express; `applicationSupport` is where per-server state is kept.
  public convenience init(
    configuration: URLSessionConfiguration,
    secrets: any SecretStore,
    activeOrigin: any ActiveOriginStore,
    background: any BackgroundExecution,
    connectivity: any Connectivity = AlwaysReachable(),
    applicationSupport: URL,
    userAgent: UserAgent
  ) {
    self.init(
      transport: URLSessionTransport(configuration: configuration), secrets: secrets,
      activeOrigin: activeOrigin, background: background, connectivity: connectivity,
      applicationSupport: applicationSupport, userAgent: userAgent)
  }

  public init(
    transport: any HTTPTransport,
    secrets: any SecretStore,
    activeOrigin: any ActiveOriginStore,
    background: any BackgroundExecution,
    connectivity: any Connectivity = AlwaysReachable(),
    applicationSupport: URL,
    userAgent: UserAgent,
    accessToken: String? = nil
  ) {
    self.transport = transport
    self.secrets = secrets
    self.activeOrigin = activeOrigin
    self.background = background
    self.connectivity = connectivity
    self.userAgent = userAgent
    store = ServerStateStore(root: applicationSupport, secrets: secrets, activeOrigin: activeOrigin)
    state = .noServer
    if let origin = activeOrigin.load() {
      client = makeClient(origin, accessToken: accessToken)
      enter(origin)
    }
  }

  // MARK: - Servers

  /// Asks `origin` whether it is an OpenDiving instance, and what it runs. Waits out the
  /// Local Network prompt rather than failing before it is answered, through the app's
  /// configuration.
  public func validate(_ origin: ServerOrigin) async throws -> ServerInfo {
    let checker: APIClient
    if let client, client.origin == origin {
      checker = client
    } else {
      checker = makeClient(origin)
    }
    let info = try await checker.instance()
    if state.origin == origin { server = info }
    return info
  }

  /// Points the app at `origin`. A session on the previous server is the caller's to sign
  /// out of first; this changes nothing stored about it.
  public func select(_ origin: ServerOrigin, info: ServerInfo? = nil) {
    activeOrigin.save(origin)
    client = makeClient(origin)
    server = info
    user = nil
    people = [:]
    enter(origin)
  }

  /// Whether the phone holds anything for `origin` that ``forget(_:)`` would remove.
  public func hasState(_ origin: ServerOrigin) -> Bool {
    store.hasState(origin)
  }

  /// Removes everything kept for `origin` — the token, the remembered account, the
  /// per-server directory — and, when it is the active server, leaves no server active. Asks
  /// nothing of the server; a sign-out first is the caller's.
  public func forget(_ origin: ServerOrigin) throws {
    try store.forget(origin)
    guard state.origin == origin else { return }
    client = nil
    server = nil
    user = nil
    people = [:]
    transition(to: .noServer)
  }

  // MARK: - Signing in and out

  /// Mails a sign-in code to `email`; the answer names the request the code belongs to.
  public func requestCode(email: String) async throws -> UUID {
    try await requireClient().requestEmailCode(email: email).requestId
  }

  /// Redeems a code. On ``SignInOutcome/signedIn`` the session is signed in, and
  /// ``loadAccount()`` is what fetches the account and the people table.
  public func verifyCode(requestID: UUID, code: String) async throws -> SignInOutcome {
    let client = try requireClient()
    let outcome = try await client.verifyEmailCode(requestID: requestID, code: code)
    switch outcome.status {
    case "authenticated":
      transition(to: .signedIn(client.origin))
      return .signedIn
    case "onboarding_required":
      return .onboardingRequired(email: outcome.email, name: outcome.name)
    case "deletion_pending":
      return .deletionPending(email: outcome.email, purgeAfter: outcome.purgeAfter)
    default:
      throw APIError.unreadableResponse("Unknown sign-in outcome \"\(outcome.status)\"")
    }
  }

  /// A cold start's refresh, then the account and the people table, as signing in loads
  /// them. A refused refresh signs out; one that never reached the server keeps the session
  /// and throws.
  public func resume() async throws {
    try await requireClient().refreshSession()
    try await loadAccount()
  }

  /// `GET /user` and every page of `GET /people`, then the server's last-account pointer and
  /// the account's form settings, then ``accountLoaded``. Returns quietly, storing nothing,
  /// when the session changed while it ran.
  public func loadAccount() async throws {
    let client = try requireClient()
    let generation = stateGeneration
    let user = try await client.currentUser()
    let people = try await APIClient.allPages { page, perPage in
      try await client.people(page: page, itemsPerPage: perPage)
    }
    guard generation == stateGeneration, state == .signedIn(client.origin) else { return }
    self.user = user
    self.people = Dictionary(people.map { ($0.uuid, $0) }) { first, _ in first }
    try? store.remember(user, for: client.origin)
    try? store.rememberLastAccount(user, for: client.origin)
    accountLoaded = true
  }

  /// Revokes the session on the server, then forgets the token and the account here. An
  /// offline phone cannot sign out: a failure that never reached the server, or any error but
  /// a refused session, changes nothing. The per-server directory stays.
  public func signOut() async throws {
    let client = try requireClient()
    try await client.signOut()
    endSession(on: client.origin)
  }

  // MARK: - Lookups

  public func person(_ uuid: UUID) -> PersonRead? {
    people[uuid]
  }

  /// The active server's client, or ``APIError/signedOut`` with none.
  public func requireClient() throws -> APIClient {
    guard let client else { throw APIError.signedOut }
    return client
  }

  // MARK: - Internals

  private func enter(_ origin: ServerOrigin) {
    if store.hasRefreshToken(origin) {
      user = store.rememberedUser(for: origin)
      transition(to: .signedIn(origin))
    } else {
      transition(to: .signingIn(origin))
    }
  }

  private func endSession(on origin: ServerOrigin) {
    try? store.endSession(for: origin)
    guard state.origin == origin else { return }
    user = nil
    people = [:]
    transition(to: .signingIn(origin))
  }

  /// Every change of ``state`` goes through here — and so does selecting the server already
  /// active, which drops the account the same way — so no load from before it counts.
  private func transition(to new: State) {
    state = new
    stateGeneration += 1
    accountLoaded = false
  }

  private func makeClient(_ origin: ServerOrigin, accessToken: String? = nil) -> APIClient {
    APIClient(
      origin: origin, transport: transport, secrets: secrets, background: background,
      userAgent: userAgent, accessToken: accessToken
    ) { [weak self] in
      await self?.endSession(on: origin)
    }
  }
}
