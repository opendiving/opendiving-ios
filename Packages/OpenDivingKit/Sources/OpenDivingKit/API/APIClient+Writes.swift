import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// Every create carries an `Idempotency-Key`: the caller chooses it once per record and keeps
// it, so a create retried after a lost reply is the same request, and the server answers it
// with the record the first one made rather than making a second.
extension APIClient {
  // MARK: - Dives

  /// `POST /dive`.
  public func createDive(_ dive: DiveCreate, idempotencyKey: UUID) async throws
    -> DiveReadWithMixtures
  {
    try await create(DiveReadWithMixtures.self, "dive", dive, idempotencyKey)
  }

  /// `PATCH /dive/{uuid}`, which sends only what `update` sets. Its answer is a message, so
  /// the dive is read again to see it.
  public func updateDive(_ uuid: UUID, _ update: DiveUpdate) async throws {
    try await authorizedChecked(
      Call(method: "PATCH", path: "dive/\(Self.wire(uuid))", body: Self.json(update)))
  }

  // MARK: - Records

  /// `POST /dive-site`.
  public func createDiveSite(_ site: DiveSiteCreate, idempotencyKey: UUID) async throws
    -> DiveSiteRead
  {
    try await create(DiveSiteRead.self, "dive-site", site, idempotencyKey)
  }

  /// `POST /person`.
  public func createPerson(_ person: PersonCreate, idempotencyKey: UUID) async throws
    -> PersonRead
  {
    try await create(PersonRead.self, "person", person, idempotencyKey)
  }

  /// `POST /trip`.
  public func createTrip(_ trip: TripCreate, idempotencyKey: UUID) async throws -> TripRead {
    try await create(TripRead.self, "trip", trip, idempotencyKey)
  }

  /// `POST /course`.
  public func createCourse(_ course: CourseCreate, idempotencyKey: UUID) async throws
    -> CourseRead
  {
    try await create(CourseRead.self, "course", course, idempotencyKey)
  }

  /// `POST /contact`: a dive centre, among others.
  public func createContact(_ contact: ContactCreate, idempotencyKey: UUID) async throws
    -> ContactRead
  {
    try await create(ContactRead.self, "contact", contact, idempotencyKey)
  }

  /// `POST /gear-item`.
  public func createGearItem(_ item: GearItemCreate, idempotencyKey: UUID) async throws
    -> GearItemRead
  {
    try await create(GearItemRead.self, "gear-item", item, idempotencyKey)
  }

  /// `POST /gear-set`.
  public func createGearSet(_ set: GearSetCreate, idempotencyKey: UUID) async throws
    -> GearSetRead
  {
    try await create(GearSetRead.self, "gear-set", set, idempotencyKey)
  }

  /// `PATCH /gear-set/{uuid}`, which sends only what `update` sets.
  public func updateGearSet(_ uuid: UUID, _ update: GearSetUpdate) async throws {
    try await authorizedChecked(
      Call(method: "PATCH", path: "gear-set/\(Self.wire(uuid))", body: Self.json(update)))
  }

  // MARK: - Dive drafts

  /// `POST /dive-draft`.
  public func createDiveDraft(_ draft: DiveDraftWrite, idempotencyKey: UUID) async throws
    -> DiveDraftRead
  {
    try await create(DiveDraftRead.self, "dive-draft", draft, idempotencyKey)
  }

  /// `GET /dive-drafts`, the most recently changed first.
  public func diveDrafts(page: Int, itemsPerPage: Int = listPageSize) async throws
    -> PaginatedListResponse<DiveDraftRead>
  {
    try await authorizedDecoded(
      PaginatedListResponse<DiveDraftRead>.self,
      Call(path: "dive-drafts", query: Self.paging(page, itemsPerPage)))
  }

  /// `GET /dive-draft/{uuid}`.
  public func diveDraft(_ uuid: UUID) async throws -> DiveDraftRead {
    try await authorizedDecoded(DiveDraftRead.self, Call(path: "dive-draft/\(Self.wire(uuid))"))
  }

  /// `PATCH /dive-draft/{uuid}` with the form's whole state, which replaces the draft's. Its
  /// answer is a message.
  public func updateDiveDraft(_ uuid: UUID, _ draft: DiveDraftWrite) async throws {
    try await authorizedChecked(
      Call(method: "PATCH", path: "dive-draft/\(Self.wire(uuid))", body: Self.json(draft)))
  }

  /// `DELETE /dive-draft/{uuid}`.
  public func deleteDiveDraft(_ uuid: UUID) async throws {
    try await authorizedChecked(Call(method: "DELETE", path: "dive-draft/\(Self.wire(uuid))"))
  }

  /// `POST /dive-draft/{uuid}/dive`: creates the dive as `POST /dive` does and deletes the
  /// draft in the same request.
  public func logDive(fromDraft uuid: UUID, _ dive: DiveCreate, idempotencyKey: UUID)
    async throws -> DiveReadWithMixtures
  {
    try await create(
      DiveReadWithMixtures.self, "dive-draft/\(Self.wire(uuid))/dive", dive, idempotencyKey)
  }

  // MARK: - Species

  /// `POST /species/resolve`: a register hit as a catalog species, whose uuid a sighting can
  /// name. Idempotent.
  public func speciesResolve(aphiaID: Int) async throws -> SpeciesRead {
    try await authorizedDecoded(
      SpeciesRead.self,
      Call(
        method: "POST", path: "species/resolve",
        body: Self.json(SpeciesResolveRequest(aphiaId: aphiaID))))
  }

  // MARK: - Sending

  private func create<Response: Decodable>(
    _ type: Response.Type, _ path: String, _ body: some Encodable, _ idempotencyKey: UUID
  ) async throws -> Response {
    try await authorizedDecoded(
      type,
      Call(
        method: "POST", path: path, body: Self.json(body),
        headers: ["Idempotency-Key": Self.wire(idempotencyKey)]))
  }
}
