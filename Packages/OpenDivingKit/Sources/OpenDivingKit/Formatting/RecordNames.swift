import Foundation

/// The name of a record a page holds only by uuid — a course's dive centre, a certification's
/// instructor, a service's shop — from what the phone holds, online or off. Nil where the phone
/// holds none, and the page leaves the row out rather than show a uuid or a placeholder.
public enum RecordNames {
  /// From the session's people table, then the pickers' rows, which name a person created on
  /// this phone too.
  public static func person(
    _ uuid: UUID?, people: [UUID: PersonRead], lookups: [PersonLookupItem]
  ) -> String? {
    guard let uuid else { return nil }
    if let name = shown(people[uuid]?.name) { return name }
    return shown(lookups.first { $0.ref.serverUUID == uuid }?.name)
  }

  /// From the pickers' contact rows.
  public static func contact(_ uuid: UUID?, lookups: [ContactLookupItem]) -> String? {
    guard let uuid else { return nil }
    return shown(lookups.first { $0.ref.serverUUID == uuid }?.name)
  }

  private static func shown(_ name: String?) -> String? {
    guard let name = name?.trimmedOfWhitespace, !name.isEmpty else { return nil }
    return name
  }
}
