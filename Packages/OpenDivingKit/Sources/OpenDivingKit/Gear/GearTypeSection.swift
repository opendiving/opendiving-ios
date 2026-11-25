import Foundation

/// The gear filed under one of the Type picker's headings on More's *Gear*, the headings in the
/// picker's order and the items in the list's. The picker's last run, under a rule rather than a
/// heading, is *Other* here, and takes gear with no type and a type the phone does not know.
public struct GearTypeSection: Equatable, Sendable, Identifiable {
  public let title: String
  public let items: [GearItemRead]

  public var id: String { title }

  public init(title: String, items: [GearItemRead]) {
    self.title = title
    self.items = items
  }

  /// The heading of the picker's run that has none.
  public static let other = "Other"

  /// The items under their headings, leaving out a heading with nothing under it.
  public static func sections(_ items: [GearItemRead]) -> [GearTypeSection] {
    let groups = FormVocabulary.gearTypeGroups
    var groupOf: [String: Int] = [:]
    for (index, group) in groups.enumerated() {
      for type in group.types { groupOf[type] = index }
    }
    var filed = Array(repeating: [GearItemRead](), count: groups.count)
    for item in items {
      filed[item.type.flatMap { groupOf[$0] } ?? groups.count - 1].append(item)
    }
    return zip(groups, filed).compactMap { group, items in
      items.isEmpty ? nil : GearTypeSection(title: group.title ?? other, items: items)
    }
  }
}
