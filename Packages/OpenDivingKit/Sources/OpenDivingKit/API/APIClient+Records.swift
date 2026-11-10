import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// The reads of the records the profile's More lists: gear and its service, courses and
// certifications, people, contacts, and the life list's single entry.
extension APIClient {
  // MARK: - Gear

  /// `GET /gear-items`, by name; archived items only with `includeArchived`.
  public func gearItems(
    page: Int, itemsPerPage: Int = listPageSize, includeArchived: Bool
  ) async throws -> PaginatedListResponse<GearItemRead> {
    try await authorizedDecoded(
      PaginatedListResponse<GearItemRead>.self,
      Call(
        path: "gear-items",
        query: Self.paging(page, itemsPerPage) + [
          URLQueryItem(name: "include_archived", value: includeArchived ? "true" : "false")
        ]))
  }

  /// `GET /gear-item/{uuid}`.
  public func gearItem(_ uuid: UUID) async throws -> GearItemRead {
    try await authorizedDecoded(GearItemRead.self, Call(path: "gear-item/\(Self.wire(uuid))"))
  }

  /// `GET /gear-set/{uuid}`.
  public func gearSet(_ uuid: UUID) async throws -> GearSetRead {
    try await authorizedDecoded(GearSetRead.self, Call(path: "gear-set/\(Self.wire(uuid))"))
  }

  /// `GET /gear-service-schedules` for one gear item, soonest due first.
  public func gearServiceSchedules(
    gearItemUUID: UUID, page: Int, itemsPerPage: Int = nestedListPageSize
  ) async throws -> PaginatedListResponse<GearServiceScheduleRead> {
    try await authorizedDecoded(
      PaginatedListResponse<GearServiceScheduleRead>.self,
      Call(
        path: "gear-service-schedules",
        query: [URLQueryItem(name: "gear_item_uuid", value: Self.wire(gearItemUUID))]
          + Self.paging(page, itemsPerPage)))
  }

  /// `GET /gear-service-schedule/{uuid}`.
  public func gearServiceSchedule(_ uuid: UUID) async throws -> GearServiceScheduleRead {
    try await authorizedDecoded(
      GearServiceScheduleRead.self, Call(path: "gear-service-schedule/\(Self.wire(uuid))"))
  }

  /// `GET /gear-service-records` for one gear item, the most recently serviced first.
  public func gearServiceRecords(
    gearItemUUID: UUID, page: Int, itemsPerPage: Int = nestedListPageSize
  ) async throws -> PaginatedListResponse<GearServiceRecordRead> {
    try await authorizedDecoded(
      PaginatedListResponse<GearServiceRecordRead>.self,
      Call(
        path: "gear-service-records",
        query: [URLQueryItem(name: "gear_item_uuid", value: Self.wire(gearItemUUID))]
          + Self.paging(page, itemsPerPage)))
  }

  /// `GET /gear-service-record/{uuid}`.
  public func gearServiceRecord(_ uuid: UUID) async throws -> GearServiceRecordRead {
    try await authorizedDecoded(
      GearServiceRecordRead.self, Call(path: "gear-service-record/\(Self.wire(uuid))"))
  }

  // MARK: - Training

  /// `GET /courses`, the latest start first and dateless last.
  public func courses(page: Int, itemsPerPage: Int = listPageSize) async throws
    -> PaginatedListResponse<CourseRead>
  {
    try await authorizedDecoded(
      PaginatedListResponse<CourseRead>.self,
      Call(path: "courses", query: Self.paging(page, itemsPerPage)))
  }

  /// `GET /certifications?course_uuid=`: the cards one course issued, in the list's order.
  public func certifications(
    courseUUID: UUID, page: Int, itemsPerPage: Int = nestedListPageSize
  ) async throws -> PaginatedListResponse<CertificationRead> {
    try await authorizedDecoded(
      PaginatedListResponse<CertificationRead>.self,
      Call(
        path: "certifications",
        query: Self.paging(page, itemsPerPage) + [
          URLQueryItem(name: "course_uuid", value: Self.wire(courseUUID))
        ]))
  }

  /// `GET /certification/{uuid}`.
  public func certification(_ uuid: UUID) async throws -> CertificationRead {
    try await authorizedDecoded(
      CertificationRead.self, Call(path: "certification/\(Self.wire(uuid))"))
  }

  // MARK: - People and contacts

  /// `GET /person/{uuid}`.
  public func person(_ uuid: UUID) async throws -> PersonRead {
    try await authorizedDecoded(PersonRead.self, Call(path: "person/\(Self.wire(uuid))"))
  }

  /// `GET /contacts`, by name.
  public func contacts(page: Int, itemsPerPage: Int = listPageSize) async throws
    -> PaginatedListResponse<ContactRead>
  {
    try await authorizedDecoded(
      PaginatedListResponse<ContactRead>.self,
      Call(path: "contacts", query: Self.paging(page, itemsPerPage)))
  }

  // MARK: - Marine life

  /// `GET /user/species/{uuid}`: the diver's history with one species, its life-list row. A
  /// 404 means no live dive of theirs records it, whether or not the catalog has it.
  public func lifeListEntry(_ uuid: UUID) async throws -> SpeciesLifeListEntry {
    try await authorizedDecoded(
      SpeciesLifeListEntry.self, Call(path: "user/species/\(Self.wire(uuid))"))
  }

  // MARK: - A record's dives

  /// `GET /dives` narrowed to the dives of one gear item, course, person or species, newest
  /// first.
  public func dives(
    _ scope: DiveListScope, page: Int, itemsPerPage: Int = nestedListPageSize
  ) async throws -> PaginatedListResponse<DiveListItem> {
    try await authorizedDecoded(
      PaginatedListResponse<DiveListItem>.self,
      Call(path: "dives", query: Self.paging(page, itemsPerPage) + [scope.queryItem]))
  }
}
