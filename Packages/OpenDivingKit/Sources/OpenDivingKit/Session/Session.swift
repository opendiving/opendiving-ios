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
  /// When ``server`` was answered.
  @ObservationIgnored private var serverAnsweredAt: Date?
  /// The servers ``validate(_:)`` is asking, for a card that shows it is updating.
  public private(set) var validating: Set<ServerOrigin> = []
  /// Why ``validate(_:)`` last failed for a server, until it next answers.
  public private(set) var validationFailures: [ServerOrigin: String] = [:]
  /// The active server's client; nil with no server.
  public private(set) var client: APIClient? = nil
  /// Every server the phone has been pointed at and not forgotten since, the active one among
  /// them, in the order each was first chosen.
  public private(set) var savedServers: [ServerOrigin] = []

  /// The account's units; metric until the account is known.
  public var units: UnitSystem { user?.units ?? .metric }

  /// Every client this session builds sends through it.
  @ObservationIgnored public let requests = RequestActivity()

  @ObservationIgnored private let transport: any HTTPTransport
  @ObservationIgnored private let secrets: any SecretStore
  @ObservationIgnored private let activeOrigin: any ActiveOriginStore
  @ObservationIgnored private let userAgent: UserAgent
  @ObservationIgnored private let now: () -> Date
  @ObservationIgnored public let store: ServerStateStore
  /// Keeps the app running while work that must not be cut off finishes: a token rotating, a
  /// queue flushing.
  @ObservationIgnored public nonisolated let background: any BackgroundExecution
  /// Whether a route is believed to exist, and the moments worth trying again.
  @ObservationIgnored public nonisolated let connectivity: any Connectivity
  /// Bumped on every change of ``state``, so a load that began before one cannot land after it.
  @ObservationIgnored private var stateGeneration = 0
  @ObservationIgnored private var mapTiles: MapTileStore?
  /// The active server's ``validate(_:)`` that screens and page heads are waiting on, which
  /// none of them cancels by leaving.
  @ObservationIgnored private var serverInfoAsk:
    (origin: ServerOrigin, task: Task<ServerInfo?, Never>)?

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

  /// `now` stands in for the clock that marks a server used, in a test.
  public init(
    transport: any HTTPTransport,
    secrets: any SecretStore,
    activeOrigin: any ActiveOriginStore,
    background: any BackgroundExecution,
    connectivity: any Connectivity = AlwaysReachable(),
    applicationSupport: URL,
    userAgent: UserAgent,
    accessToken: String? = nil,
    now: @escaping () -> Date = { Date() }
  ) {
    self.transport = CountingTransport(base: transport, activity: requests)
    self.secrets = secrets
    self.activeOrigin = activeOrigin
    self.background = background
    self.connectivity = connectivity
    self.userAgent = userAgent
    self.now = now
    store = ServerStateStore(root: applicationSupport, secrets: secrets, activeOrigin: activeOrigin)
    state = .noServer
    if let origin = activeOrigin.load() {
      // The active server of an install from before the list was kept.
      try? store.save(origin)
      client = makeClient(origin, accessToken: accessToken)
      enter(origin)
      try? store.markUsed(origin, at: now())
    }
    savedServers = store.savedServers()
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
    validating.insert(origin)
    validationFailures[origin] = nil
    defer { validating.remove(origin) }
    let info: ServerInfo
    do {
      info = try await checker.instance()
    } catch let error as CancellationError {
      throw error
    } catch {
      validationFailures[origin] = ServerProblem(APIError(error), origin: origin).message
      throw error
    }
    if state.origin == origin {
      server = info
      serverAnsweredAt = now()
    }
    // Only a saved server's build is kept: a typed one may never be chosen.
    if let health = info.health, store.savedServers().contains(origin) {
      try? store.rememberHealth(health, for: origin)
    }
    return info
  }

  /// Points the app at `origin` and saves it, signed in there when the phone still holds a
  /// session for it, and marks both it and the server it leaves as used now. The previous
  /// server keeps its session and everything else stored for it.
  public func select(_ origin: ServerOrigin, info: ServerInfo? = nil) {
    let used = now()
    if let left = state.origin, left != origin {
      try? store.markUsed(left, at: used)
    }
    activeOrigin.save(origin)
    try? store.save(origin)
    try? store.markUsed(origin, at: used)
    if let health = info?.health { try? store.rememberHealth(health, for: origin) }
    savedServers = store.savedServers()
    replaceClient(with: makeClient(origin))
    server = info
    serverAnsweredAt = info.map { _ in now() }
    user = nil
    people = [:]
    enter(origin)
  }

  /// The active server's card: the build it runs, as it last answered ``validate(_:)`` in this
  /// launch or any before, and whether it is being asked again.
  public var serverCard: ServerCardContent? {
    state.origin.map { card(for: $0) }
  }

  /// `origin`'s card, from what this session or the phone last heard from it.
  public func card(for origin: ServerOrigin, answered: ServerInfo? = nil) -> ServerCardContent {
    let live = answered ?? (state.origin == origin ? server : nil)
    return ServerCardContent(
      origin: origin, health: live?.health ?? store.health(origin),
      isUpdating: validating.contains(origin), updateFailure: validationFailures[origin])
  }

  /// How long the active server's answer stands before ``loadServerInfo()`` asks again: long
  /// enough that the screen a *Continue* lands on does not repeat what it just asked.
  public static let serverInfoFreshness: TimeInterval = 60

  /// Asks the active server again what it runs, unless it answered within
  /// ``serverInfoFreshness``; a failure leaves the build it last reported.
  public func loadServerInfo() async {
    guard let origin = state.origin, !isFresh(origin) else { return }
    _ = await askServerInfo(origin)
  }

  private func isFresh(_ origin: ServerOrigin) -> Bool {
    guard server?.origin == origin, let answeredAt = serverAnsweredAt else { return false }
    return now().timeIntervalSince(answeredAt) < Self.serverInfoFreshness
  }

  /// The active server's answer, joining an ask already on its way. Nil when it cannot be had,
  /// or when a ``validate(_:)`` of somebody else's is already asking.
  private func askServerInfo(_ origin: ServerOrigin) async -> ServerInfo? {
    if let ask = serverInfoAsk, ask.origin == origin { return await ask.task.value }
    guard !validating.contains(origin) else { return nil }
    let task = Task { try? await self.validate(origin) }
    serverInfoAsk = (origin, task)
    let info = await task.value
    if serverInfoAsk?.origin == origin { serverInfoAsk = nil }
    return info
  }

  /// Whether the phone holds anything for `origin` that ``forget(_:)`` would remove.
  public func hasState(_ origin: ServerOrigin) -> Bool {
    store.hasState(origin)
  }

  /// Whether the phone holds a session for `origin`, active or not.
  public func isSignedIn(to origin: ServerOrigin) -> Bool {
    store.hasRefreshToken(origin)
  }

  /// The account signed in to `origin`, as last read; nil when signed out there or before
  /// one has loaded.
  public func account(on origin: ServerOrigin) -> UserRead? {
    state.origin == origin ? user : store.rememberedUser(for: origin)
  }

  /// Removes everything kept for `origin` — the token, the remembered account, the
  /// per-server directory — and, when it is the active server, leaves no server active. Asks
  /// nothing of the server; a sign-out first is the caller's.
  public func forget(_ origin: ServerOrigin) throws {
    defer { savedServers = store.savedServers() }
    try store.forget(origin)
    guard state.origin == origin else { return }
    replaceClient(with: nil)
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
    try await signOut(of: requireClient().origin)
  }

  /// ``signOut()`` for any server the phone holds a session for, the active one or another.
  public func signOut(of origin: ServerOrigin) async throws {
    let client: APIClient
    if let active = self.client, active.origin == origin {
      client = active
    } else {
      client = makeClient(origin)
    }
    try await client.signOut()
    endSession(on: origin)
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

  /// ``requireClient()`` for a read a screen starts on its own, which fails at once with
  /// ``APIError/noRoute`` while the phone believes it has no route rather than waiting a
  /// minute for one; the screen reads again when ``Connectivity/moments()`` says one appeared.
  public func routedClient() throws -> APIClient {
    let client = try requireClient()
    guard connectivity.isRouteAvailable else { throw APIError.noRoute }
    return client
  }

  // MARK: - Map tiles

  /// The active server's map tiles; nil with no server.
  public func mapTileStore() -> MapTileStore? {
    guard let client else { return nil }
    if let mapTiles, mapTiles.client === client { return mapTiles }
    let tiles = MapTileStore(
      client: client,
      directory: store.directory(for: client.origin)
        .appendingPathComponent("MapTiles", isDirectory: true),
      language: Locale.preferredLanguages.first)
    mapTiles = tiles
    return tiles
  }

  /// The active server's config, asked for when it has not answered since launch — or when it
  /// draws tiles but had no credit for them yet, which it learns from its renderer after it
  /// starts. Asked again no sooner than ``serverInfoFreshness`` after an answer, and once for
  /// every page head and screen waiting at the same time. Nil when it cannot be had.
  public func mapConfig() async -> InstanceConfigRead? {
    if let config = server?.config, config.mapTiles != true || config.mapAttribution != nil {
      return config
    }
    guard let origin = state.origin else { return nil }
    if isFresh(origin) { return server?.config }
    return await askServerInfo(origin)?.config
  }

  // MARK: - OpenDiving Commons

  /// Whether the active server edits the Commons, so that proposing is offered at all: not
  /// until it has answered, and not on a config that does not say.
  public var isCommonsPrimary: Bool {
    server?.config.commonsPrimary == true
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

  /// Every client the session lets go of goes through here, and has its requests cut off.
  private func replaceClient(with new: APIClient?) {
    client?.cancelAll()
    client = new
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
