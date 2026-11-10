import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The record a page's dives are narrowed to: `GET /dives`' filter for it.
public enum DiveListScope: Hashable, Sendable {
  case gearItem(UUID)
  case course(UUID)
  case person(UUID)
  case species(UUID)

  var queryItem: URLQueryItem {
    switch self {
    case .gearItem(let uuid): URLQueryItem(name: "gear_item_uuid", value: APIClient.wire(uuid))
    case .course(let uuid): URLQueryItem(name: "course_uuid", value: APIClient.wire(uuid))
    case .person(let uuid): URLQueryItem(name: "person_uuid", value: APIClient.wire(uuid))
    case .species(let uuid): URLQueryItem(name: "species_uuid", value: APIClient.wire(uuid))
    }
  }
}
