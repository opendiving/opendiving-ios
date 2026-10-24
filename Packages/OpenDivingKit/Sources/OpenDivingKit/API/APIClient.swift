import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The calls this app makes to one server, and that server's session: the access token in
/// memory, the refresh token in the ``SecretStore``.
///
/// A request the server answers 401 refreshes the session once and is retried once — rebuilt,
/// not replayed, so the retry carries the new bearer and, on `/auth/logout`, the rotated
/// cookie — and a second 401 ends the session. Concurrent 401s share one refresh: the loser of
/// two refreshes racing with one token is refused even inside the API's reuse grace, which
/// answers only a presentation retried seconds later.
public actor APIClient {
  /// Every list this app reads is fetched 50 at a time; the API's own default is 10.
  public static let listPageSize = 50
  /// A trip's or a site's dives.
  public static let nestedListPageSize = 100

  public nonisolated let origin: ServerOrigin

  private let transport: any HTTPTransport
  private let secrets: any SecretStore
  private let background: any BackgroundExecution
  private let userAgent: UserAgent
  private let onSessionEnded: (@Sendable () async -> Void)?
  private let refreshRetryPause: Duration
  private var accessToken: String?
  private var refreshTask: Task<String, any Error>?

  /// `onSessionEnded` runs when the server refuses the session, after the refresh token has
  /// been removed from `secrets`. `refreshRetryPause` is how long a refresh whose reply was
  /// lost waits before it presents the same cookie again.
  public init(
    origin: ServerOrigin,
    transport: any HTTPTransport,
    secrets: any SecretStore,
    background: any BackgroundExecution,
    userAgent: UserAgent,
    accessToken: String? = nil,
    refreshRetryPause: Duration = .seconds(2),
    onSessionEnded: (@Sendable () async -> Void)? = nil
  ) {
    self.origin = origin
    self.transport = transport
    self.secrets = secrets
    self.background = background
    self.userAgent = userAgent
    self.accessToken = accessToken
    self.refreshRetryPause = refreshRetryPause
    self.onSessionEnded = onSessionEnded
  }

  private var account: String { origin.description }

  // MARK: - The server

  /// `GET /config`, then `GET /health`. A config that is not JSON carrying
  /// `registration_mode` and `project_operated` is ``APIError/notAnInstance``; no answer at
  /// all is ``APIError/unreachable(_:)``, after one request.
  public func instance() async throws -> ServerInfo {
    let (data, response) = try await perform(Call(path: "config"), bearer: nil)
    guard (200..<300).contains(response.statusCode),
      let config = try? APICoding.decoder().decode(InstanceConfigRead.self, from: data)
    else { throw APIError.notAnInstance }
    let health = try? await decoded(HealthRead.self, Call(path: "health"))
    return ServerInfo(origin: origin, config: config, health: health)
  }

  // MARK: - Signing in and out

  /// `POST /auth/email/request`: mails a six-digit code. The answer is the same whether or
  /// not the address has an account.
  public func requestEmailCode(email: String) async throws -> EmailAuthRequestResponse {
    let body = try APICoding.encoder().encode(["email": email])
    return try await decoded(
      EmailAuthRequestResponse.self, Call(method: "POST", path: "auth/email/request", body: body))
  }

  /// `POST /auth/email/verify-code`. On `authenticated` the session starts here: the access
  /// token is kept in memory and the refresh token in the ``SecretStore``. A 401 is the
  /// server's answer about the code, not an expired session; an uninvited address on an
  /// invite-only instance is a 403 whose sentence says so.
  ///
  /// Always asks for the `extended` idle timeout: the Kit's one caller is a phone that may sit
  /// on a boat for weeks, and the server keeps a standard window for the browsers.
  public func verifyEmailCode(requestID: UUID, code: String) async throws -> AuthOutcome {
    let body = try APICoding.encoder().encode([
      "request_id": Self.wire(requestID), "code": code, "idle_timeout": "extended",
    ])
    let (data, response) = try await perform(
      Call(method: "POST", path: "auth/email/verify-code", body: body, mintsSession: true),
      bearer: nil)
    let outcome = try decode(AuthOutcome.self, data, response)
    if outcome.status == "authenticated", let token = outcome.accessToken {
      if let cookie = RefreshCookie.value(inSetCookie: setCookie(response)) {
        try store(cookie)
      }
      accessToken = token
    }
    return outcome
  }

  /// Rotates the session now, as a cold start does. Throws ``APIError/signedOut`` when the
  /// server refuses it, and keeps the session when the request never reached the server.
  public func refreshSession() async throws {
    _ = try await renewedAccessToken(replacing: accessToken)
  }

  /// `POST /auth/logout`, which revokes the session on the server. It wants a live access
  /// token as well as the cookie, so one that aged out is refreshed first, as on any other
  /// route. A failure that never reached the server, or any error but a refused session,
  /// leaves the session as it was; a server that refuses the session ends it, as anywhere.
  public func signOut() async throws {
    let (data, response) = try await authorized(
      Call(method: "POST", path: "auth/logout", sendsRefreshCookie: true))
    try check(data, response)
    accessToken = nil
    try? secrets.removeSecret(for: account)
  }

  // MARK: - The account

  /// `GET /user`.
  public func currentUser() async throws -> UserRead {
    try await authorizedDecoded(UserRead.self, Call(path: "user"))
  }

  /// `GET /user/checkin-details`.
  public func checkinDetails() async throws -> CheckinDetailsRead {
    try await authorizedDecoded(CheckinDetailsRead.self, Call(path: "user/checkin-details"))
  }

  /// `GET /user/dive-stats`.
  public func diveStats() async throws -> UserDiveStatsRead {
    try await authorizedDecoded(UserDiveStatsRead.self, Call(path: "user/dive-stats"))
  }

  /// `GET /user/portrait?v=`, `version` being the account's `portraitSha256`. Ask only when
  /// that is not null.
  public func portrait(version: String, etag: String?) async throws
    -> ConditionalFetch<FetchedBytes>
  {
    try await conditionalBytes(
      Call(path: "user/portrait", query: [URLQueryItem(name: "v", value: version)], etag: etag))
  }

  /// `GET /people`, one page.
  public func people(page: Int, itemsPerPage: Int = listPageSize) async throws
    -> PaginatedListResponse<PersonRead>
  {
    try await authorizedDecoded(
      PaginatedListResponse<PersonRead>.self,
      Call(path: "people", query: Self.paging(page, itemsPerPage)))
  }

  // MARK: - Dives

  /// `GET /dives`, newest first, optionally one trip's or one site's alone.
  public func dives(
    page: Int, itemsPerPage: Int = listPageSize, tripUUID: UUID? = nil, diveSiteUUID: UUID? = nil
  ) async throws -> PaginatedListResponse<DiveListItem> {
    var query = Self.paging(page, itemsPerPage)
    if let tripUUID {
      query.append(URLQueryItem(name: "trip_uuid", value: Self.wire(tripUUID)))
    }
    if let diveSiteUUID {
      query.append(URLQueryItem(name: "dive_site_uuid", value: Self.wire(diveSiteUUID)))
    }
    return try await authorizedDecoded(
      PaginatedListResponse<DiveListItem>.self, Call(path: "dives", query: query))
  }

  /// `GET /dive/{uuid}`.
  public func dive(_ uuid: UUID) async throws -> DiveReadWithMixtures {
    try await authorizedDecoded(DiveReadWithMixtures.self, Call(path: "dive/\(Self.wire(uuid))"))
  }

  /// `GET /dive/{uuid}/neighbors`.
  public func neighbors(ofDive uuid: UUID) async throws -> DiveNeighbors {
    try await authorizedDecoded(
      DiveNeighbors.self, Call(path: "dive/\(Self.wire(uuid))/neighbors"))
  }

  /// `GET /dive/{uuid}/recording/{rid}/profile`, sent with the stored `ETag`, which is opaque.
  /// A recording with no profile is a 404.
  public func profile(dive: UUID, recording: UUID, etag: String?) async throws
    -> ConditionalFetch<RecordingProfileRead>
  {
    let call = Call(
      path: "dive/\(Self.wire(dive))/recording/\(Self.wire(recording))/profile", etag: etag)
    let (data, response) = try await authorized(call)
    if response.statusCode == 304 { return .notModified }
    return .fetched(
      try decode(RecordingProfileRead.self, data, response),
      etag: response.value(forHTTPHeaderField: "ETag"))
  }

  // MARK: - Trips, sites, courses, contacts, species

  /// `GET /trips`, the latest first.
  public func trips(page: Int, itemsPerPage: Int = listPageSize) async throws
    -> PaginatedListResponse<TripRead>
  {
    try await authorizedDecoded(
      PaginatedListResponse<TripRead>.self,
      Call(path: "trips", query: Self.paging(page, itemsPerPage)))
  }

  /// `GET /trip/{uuid}`.
  public func trip(_ uuid: UUID) async throws -> TripRead {
    try await authorizedDecoded(TripRead.self, Call(path: "trip/\(Self.wire(uuid))"))
  }

  /// `GET /dive-sites`, most recently dived first — the web list's order, not the API's
  /// default by name.
  public func diveSites(page: Int, itemsPerPage: Int = listPageSize) async throws
    -> PaginatedListResponse<DiveSiteRead>
  {
    var query = Self.paging(page, itemsPerPage)
    query.append(URLQueryItem(name: "sort", value: "last_dived_on"))
    return try await authorizedDecoded(
      PaginatedListResponse<DiveSiteRead>.self, Call(path: "dive-sites", query: query))
  }

  /// `GET /dive-site/{uuid}`.
  public func diveSite(_ uuid: UUID) async throws -> DiveSiteRead {
    try await authorizedDecoded(DiveSiteRead.self, Call(path: "dive-site/\(Self.wire(uuid))"))
  }

  /// `GET /course/{uuid}`.
  public func course(_ uuid: UUID) async throws -> CourseRead {
    try await authorizedDecoded(CourseRead.self, Call(path: "course/\(Self.wire(uuid))"))
  }

  /// `GET /contact/{uuid}`.
  public func contact(_ uuid: UUID) async throws -> ContactRead {
    try await authorizedDecoded(ContactRead.self, Call(path: "contact/\(Self.wire(uuid))"))
  }

  /// `GET /user/species`, the life list, optionally what was seen at one site alone.
  public func speciesLifeList(
    diveSiteUUID: UUID? = nil, page: Int, itemsPerPage: Int = listPageSize
  ) async throws -> PaginatedListResponse<SpeciesLifeListEntry> {
    var query = Self.paging(page, itemsPerPage)
    if let diveSiteUUID {
      query.append(URLQueryItem(name: "dive_site_uuid", value: Self.wire(diveSiteUUID)))
    }
    return try await authorizedDecoded(
      PaginatedListResponse<SpeciesLifeListEntry>.self, Call(path: "user/species", query: query))
  }

  /// `GET /species/{uuid}`: one species from the catalog, with its photo's credit. The
  /// catalog is global, so any signed-in account reads any species.
  public func species(_ uuid: UUID) async throws -> SpeciesRead {
    try await authorizedDecoded(SpeciesRead.self, Call(path: "species/\(Self.wire(uuid))"))
  }

  /// `GET /species/{uuid}/photo?v=`, `version` being the species' `photoSha256`. The one
  /// bytes route that takes no token.
  public func speciesPhoto(_ uuid: UUID, version: String) async throws -> FetchedBytes {
    let call = Call(
      path: "species/\(Self.wire(uuid))/photo", query: [URLQueryItem(name: "v", value: version)])
    let (data, response) = try await perform(call, bearer: nil)
    try check(data, response)
    return FetchedBytes(data: data, contentType: response.value(forHTTPHeaderField: "Content-Type"))
  }

  // MARK: - Certifications

  /// `GET /certifications`, newest `certified_on` first and dateless last.
  public func certifications(page: Int, itemsPerPage: Int = listPageSize) async throws
    -> PaginatedListResponse<CertificationRead>
  {
    try await authorizedDecoded(
      PaginatedListResponse<CertificationRead>.self,
      Call(path: "certifications", query: Self.paging(page, itemsPerPage)))
  }

  /// `GET /certification/{uuid}/file/{side}`, `side` being `front` or `back`. A side with no
  /// file is a 404.
  public func certificationFile(_ uuid: UUID, side: String, etag: String?) async throws
    -> ConditionalFetch<FetchedBytes>
  {
    try await conditionalBytes(
      Call(path: "certification/\(Self.wire(uuid))/file/\(side)", etag: etag))
  }

  // MARK: - Paging

  /// Every page of a list, fetched in turn while the server says there is more.
  public static func allPages<Item: Codable & Sendable>(
    itemsPerPage: Int = listPageSize,
    _ fetch:
      @Sendable (_ page: Int, _ itemsPerPage: Int) async throws -> PaginatedListResponse<
        Item
      >
  ) async throws -> [Item] {
    var items: [Item] = []
    var page = 1
    while true {
      let response = try await fetch(page, itemsPerPage)
      items += response.data
      // An empty page that claims more would otherwise be asked for forever.
      guard response.hasMore, !response.data.isEmpty else { return items }
      page += 1
    }
  }

  // MARK: - Sending

  struct Call {
    var method = "GET"
    var path: String
    var query: [URLQueryItem] = []
    var body: Data?
    /// A `multipart/form-data` body, written to a file and uploaded from it; never with `body`.
    var parts: [MultipartPart] = []
    var headers: [String: String] = [:]
    /// `/auth/refresh` and `/auth/logout`, the two routes that read the refresh cookie.
    var sendsRefreshCookie = false
    /// A 401 here is the answer, not an expired session.
    var mintsSession = false
    var etag: String?
    /// Seconds before the request gives up; nil keeps the configuration's.
    var timeout: TimeInterval?
  }

  static func paging(_ page: Int, _ itemsPerPage: Int) -> [URLQueryItem] {
    [
      URLQueryItem(name: "page", value: String(page)),
      URLQueryItem(name: "items_per_page", value: String(itemsPerPage)),
    ]
  }

  static func wire(_ uuid: UUID) -> String {
    uuid.uuidString.lowercased()
  }

  /// A request body, encoded so that a local ``RecordRef`` throws rather than being sent.
  static func json(_ value: some Encodable) throws -> Data {
    try APICoding.requestEncoder().encode(value)
  }

  /// Built at send time, so a retry reads the refresh token the store holds now. A multipart
  /// call's body is written to a new file, returned beside the request for the caller to
  /// upload and remove.
  private func request(_ call: Call, bearer: String?) throws -> (URLRequest, bodyFile: URL?) {
    var components = URLComponents(
      url: origin.apiBaseURL.appendingPathComponent(call.path), resolvingAgainstBaseURL: false)
    if !call.query.isEmpty {
      components?.queryItems = call.query
      // A query value may carry a UTC offset, and a `+` left bare is read as a space.
      let query = components?.percentEncodedQuery
      components?.percentEncodedQuery = query?.replacingOccurrences(of: "+", with: "%2B")
    }
    guard let url = components?.url else { throw APIError.unreadableResponse(call.path) }
    var request = URLRequest(url: url)
    request.httpMethod = call.method
    request.setValue(userAgent.headerValue, forHTTPHeaderField: "User-Agent")
    if let timeout = call.timeout {
      request.timeoutInterval = timeout
    }
    if let body = call.body {
      request.httpBody = body
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    for (field, value) in call.headers {
      request.setValue(value, forHTTPHeaderField: field)
    }
    if let bearer {
      request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
    }
    if call.sendsRefreshCookie, let token = try readRefreshToken() {
      request.setValue("\(RefreshCookie.name)=\(token)", forHTTPHeaderField: "Cookie")
    }
    if let etag = call.etag {
      request.setValue(etag, forHTTPHeaderField: "If-None-Match")
    }
    guard !call.parts.isEmpty else { return (request, nil) }
    let boundary = MultipartBody.boundary()
    request.setValue(
      MultipartBody.contentType(boundary: boundary), forHTTPHeaderField: "Content-Type")
    return (request, try MultipartBody.write(call.parts, boundary: boundary))
  }

  private func perform(_ call: Call, bearer: String?) async throws -> (Data, HTTPURLResponse) {
    let (request, bodyFile) = try request(call, bearer: bearer)
    defer {
      if let bodyFile { try? FileManager.default.removeItem(at: bodyFile) }
    }
    do {
      if let bodyFile {
        return try await transport.upload(request, fromFile: bodyFile)
      }
      return try await transport.send(request)
    } catch let error as URLError {
      throw APIError.unreachable(
        TransportFailure(code: error.code.rawValue, message: error.localizedDescription))
    }
  }

  func authorized(_ call: Call) async throws -> (Data, HTTPURLResponse) {
    let token = try await currentAccessToken()
    let first = try await perform(call, bearer: token)
    guard first.1.statusCode == 401, !call.mintsSession else { return first }
    let renewed = try await renewedAccessToken(replacing: token)
    let second = try await perform(call, bearer: renewed)
    if second.1.statusCode == 401 {
      await endSession()
      throw APIError.signedOut
    }
    return second
  }

  private func decoded<T: Decodable>(_ type: T.Type, _ call: Call) async throws -> T {
    let (data, response) = try await perform(call, bearer: nil)
    return try decode(type, data, response)
  }

  func authorizedDecoded<T: Decodable>(_ type: T.Type, _ call: Call) async throws -> T {
    let (data, response) = try await authorized(call)
    return try decode(type, data, response)
  }

  /// For a route whose success carries nothing to read: a `PATCH` answering a message, a
  /// `DELETE`.
  func authorizedChecked(_ call: Call) async throws {
    let (data, response) = try await authorized(call)
    try check(data, response)
  }

  private func conditionalBytes(_ call: Call) async throws -> ConditionalFetch<FetchedBytes> {
    let (data, response) = try await authorized(call)
    if response.statusCode == 304 { return .notModified }
    try check(data, response)
    return .fetched(
      FetchedBytes(data: data, contentType: response.value(forHTTPHeaderField: "Content-Type")),
      etag: response.value(forHTTPHeaderField: "ETag"))
  }

  func check(_ data: Data, _ response: HTTPURLResponse) throws {
    guard !(200..<300).contains(response.statusCode) else { return }
    let detail = try? APICoding.decoder().decode(ErrorDetail.self, from: data)
    throw APIError.http(status: response.statusCode, message: detail?.message)
  }

  func decode<T: Decodable>(_ type: T.Type, _ data: Data, _ response: HTTPURLResponse)
    throws -> T
  {
    try check(data, response)
    do {
      return try APICoding.decoder().decode(type, from: data)
    } catch {
      throw APIError.unreadableResponse(String(describing: error))
    }
  }

  private func setCookie(_ response: HTTPURLResponse) -> String? {
    response.value(forHTTPHeaderField: "Set-Cookie")
  }

  // MARK: - Tokens

  private func currentAccessToken() async throws -> String {
    if let accessToken { return accessToken }
    return try await renewedAccessToken(replacing: nil)
  }

  /// A token newer than `stale`: one another caller's refresh already produced, the one a
  /// refresh in flight is about to, or a new refresh's.
  private func renewedAccessToken(replacing stale: String?) async throws -> String {
    if let accessToken, accessToken != stale { return accessToken }
    if let refreshTask { return try await refreshTask.value }
    let task = Task { try await self.rotate() }
    refreshTask = task
    defer { refreshTask = nil }
    return try await task.value
  }

  /// How long one refresh may take: well inside the API's reuse grace, so that a retry after
  /// a lost reply lands while the server still holds the pair it minted.
  static let refreshTimeout: TimeInterval = 20

  /// `POST /auth/refresh`, inside a background-execution assertion held from the first send
  /// until the rotated token is written, so that suspension cannot lose the only live copy of
  /// it.
  ///
  /// The server spends the presented token before it answers, so a reply lost on the way back
  /// leaves the phone holding a spent cookie. Inside the API's reuse grace, presenting it again
  /// is answered with the pair the first presentation minted — so a transport failure is
  /// retried with the same cookie after a pause, which lets the first request leave the gap
  /// between the server spending the token and holding its pair; a 401 to that retry may be
  /// the gap itself and is tried once more. A transport failure on a retry keeps the token for
  /// the next request; a 401 to the last ends the session, as any refused refresh does.
  private func rotate() async throws -> String {
    guard try readRefreshToken() != nil else {
      await endSession()
      throw APIError.signedOut
    }
    let assertion = await background.begin(name: "Refreshing the OpenDiving session")
    let result: Result<String?, any Error>
    do {
      result = .success(try await refreshRetryingALostReply())
    } catch {
      result = .failure(error)
    }
    await background.end(assertion)
    guard let token = try result.get() else {
      await endSession()
      throw APIError.signedOut
    }
    return token
  }

  /// The rotated access token, or nil when the server refused the cookie.
  private func refreshRetryingALostReply() async throws -> String? {
    do {
      return try await refreshOnce()
    } catch APIError.unreachable {
      try await Task.sleep(for: refreshRetryPause)
      if let token = try await refreshOnce() { return token }
      try await Task.sleep(for: refreshRetryPause)
      return try await refreshOnce()
    }
  }

  private func refreshOnce() async throws -> String? {
    let (data, response) = try await perform(
      Call(
        method: "POST", path: "auth/refresh", sendsRefreshCookie: true, mintsSession: true,
        timeout: Self.refreshTimeout),
      bearer: nil)
    guard response.statusCode != 401 else { return nil }
    let body = try decode(RefreshResponse.self, data, response)
    if let token = RefreshCookie.value(inSetCookie: setCookie(response)) {
      try store(token)
    }
    accessToken = body.accessToken
    return body.accessToken
  }

  private func readRefreshToken() throws -> String? {
    do {
      return try secrets.secret(for: account)
    } catch {
      throw APIError.secretStore(String(describing: error))
    }
  }

  private func store(_ refreshToken: String) throws {
    do {
      try secrets.setSecret(refreshToken, for: account)
    } catch {
      throw APIError.secretStore(String(describing: error))
    }
  }

  private func endSession() async {
    accessToken = nil
    try? secrets.removeSecret(for: account)
    await onSessionEnded?()
  }
}
