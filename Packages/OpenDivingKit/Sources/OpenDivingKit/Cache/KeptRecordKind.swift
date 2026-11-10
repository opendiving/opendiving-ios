import Foundation

/// Where the phone keeps the copies of one kind of record page, and which kept lists the page
/// shows beside the record, which go when it goes.
public struct KeptRecordKind<Record: Codable & Sendable>: Sendable {
  let folder: String
  let uuid: @Sendable (Record) -> UUID
  let lists: @Sendable (UUID) -> [String]
}

extension KeptRecordKind where Record == GearItemRead {
  /// A gear item's page, with its dives and its service.
  public static var gearItem: Self {
    Self(folder: "gear-items", uuid: \.uuid) { uuid in
      [
        PageCacheKey<DiveListItem>.gearItemDives(uuid).name,
        PageCacheKey<GearServiceScheduleRead>.gearServiceSchedules(uuid).name,
        PageCacheKey<GearServiceRecordRead>.gearServiceRecords(uuid).name,
      ]
    }
  }
}

extension KeptRecordKind where Record == CourseRead {
  /// A course's page, with its dives and the certifications it issued.
  public static var course: Self {
    Self(folder: "courses", uuid: \.uuid) { uuid in
      [
        PageCacheKey<DiveListItem>.courseDives(uuid).name,
        PageCacheKey<CertificationRead>.courseCertifications(uuid).name,
      ]
    }
  }
}

extension KeptRecordKind where Record == CertificationRead {
  /// A certification's page.
  public static var certification: Self {
    Self(folder: "certifications", uuid: \.uuid) { _ in [] }
  }
}

extension KeptRecordKind where Record == PersonRead {
  /// A person's page, with the dives together.
  public static var person: Self {
    Self(folder: "people", uuid: \.uuid) { uuid in
      [PageCacheKey<DiveListItem>.personDives(uuid).name]
    }
  }
}

extension KeptRecordKind where Record == SpeciesPage {
  /// A species' page, with the dives it was seen on.
  public static var species: Self {
    Self(folder: "species", uuid: \.species.uuid) { uuid in
      [PageCacheKey<DiveListItem>.speciesDives(uuid).name]
    }
  }
}
