import Foundation

/// What a course's *Add dives* and *Add certifications* offer and do: the diver's dives and cards
/// not on the course yet, a row each, and each one picked moved onto it by an edit of its own,
/// since the API moves one record at a time.
public enum CourseAttach {
  /// A row to pick: what names the record, over the line that tells it from its neighbours.
  public struct Row: Hashable, Sendable {
    public var title: String
    public var detail: String
  }

  /// `#212 Blue Hole`, over its day and time, its time in the water and its deepest point.
  public static func row(_ dive: DiveListItem, units: UnitSystem) -> Row {
    Row(
      title: DiveTitles.title(number: dive.diveNumber, siteNames: dive.diveSites.map(\.name)),
      detail: [
        DateText.diveDateTime(dive.startTime),
        DateText.minutes(seconds: dive.submergedTime),
        dive.maxDepth.map { UnitFormat.depth($0, units, decimals: 0) },
      ].compactMap { $0 }.joined(separator: " · "))
  }

  /// The card's name, over its agency and the day it was certified, where it has one.
  public static func row(_ certification: CertificationRead) -> Row {
    Row(
      title: certification.name,
      detail: [
        VocabularyLabels.certificationAgency(
          certification.agency, other: certification.agencyOther),
        certification.certifiedOn.map { DateText.date($0) },
      ].compactMap { $0 }.joined(separator: " · "))
  }

  /// What the list's button says: `Add dives` with nothing picked, then `Add 1 dive`,
  /// `Add 3 dives`.
  public static func addLabel(_ count: Int, one: String, many: String) -> String {
    switch count {
    case 0: "Add \(many)"
    case 1: "Add 1 \(one)"
    default: "Add \(count) \(many)"
    }
  }

  /// The dives the list may offer: those on another course or none. Picking one on another course
  /// moves it, as choosing this course in its own form would.
  public static func offered(_ dives: [DiveListItem], course: UUID) -> [DiveListItem] {
    dives.filter { $0.courseUuid != course }
  }

  /// The cards the list may offer, on the same terms as its dives.
  public static func offered(_ certifications: [CertificationRead], course: UUID)
    -> [CertificationRead]
  {
    certifications.filter { $0.courseUuid != course }
  }

  /// Queues each dive's move onto the course; nil once every one is queued, else what the
  /// screen says. The moves queued before a failure stay queued.
  @MainActor
  public static func attach(dives: [UUID], to course: UUID, in outbox: OutboxModel) -> String? {
    var update = DiveUpdate()
    update.course = .value(.server(course))
    return queue(dives.map { .updateDive(.server($0), update) }, in: outbox)
  }

  /// Queues each card's move onto the course, as ``attach(dives:to:in:)`` does a dive's.
  @MainActor
  public static func attach(certifications: [UUID], to course: UUID, in outbox: OutboxModel)
    -> String?
  {
    var update = CertificationUpdate()
    update.course = .value(.server(course))
    return queue(certifications.map { .updateCertification(.server($0), update) }, in: outbox)
  }

  @MainActor
  private static func queue(_ operations: [OutboxOperation], in outbox: OutboxModel) -> String? {
    do {
      for operation in operations { try outbox.queue(operation) }
      return nil
    } catch {
      return RecordSheetModel<CourseFormValues>.sentence(error)
    }
  }
}

extension PagedList where Item == DiveListItem {
  /// Every dive the diver has, newest first, for a list to pick from; with no route it asks for
  /// nothing.
  public static func allDives(_ session: Session) -> PagedList<DiveListItem> {
    PagedList(session: session, routed: true) { client, page, itemsPerPage in
      try await client.dives(page: page, itemsPerPage: itemsPerPage)
    }
  }
}
