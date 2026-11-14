import Foundation

/// Permissions gathered by the content they reach, as the web lays them out: a group per kind
/// of content in the order the list first names it, and its actions read, then create & edit,
/// then delete.
public struct PermissionGroup: Hashable, Sendable, Identifiable {
  public struct Permission: Hashable, Sendable, Identifiable {
    /// The permission as the API names it, `dives:read`.
    public let scope: String
    public let label: String
    fileprivate let order: Int

    public var id: String { scope }
  }

  public let resource: String
  public let label: String
  public let permissions: [Permission]

  public var id: String { resource }

  /// What a key may do to this content, `Read, Create & edit`.
  public var actions: String { permissions.map(\.label).joined(separator: ", ") }

  /// What VoiceOver reads for one of the group's permissions, `Create & edit dives`.
  public func spoken(_ permission: Permission) -> String {
    permission.label + " " + label.lowercased()
  }

  public static func groups(_ scopes: [String]) -> [PermissionGroup] {
    var resources: [String] = []
    var permissions: [String: [Permission]] = [:]
    for scope in scopes {
      let parts = scope.split(separator: ":", maxSplits: 1).map(String.init)
      let resource = parts.first ?? scope
      let action = parts.count > 1 ? parts[1] : scope
      if permissions[resource] == nil { resources.append(resource) }
      let known = actionLabels[action]
      permissions[resource, default: []].append(
        Permission(scope: scope, label: known?.label ?? spaced(action), order: known?.order ?? 4))
    }
    return resources.map { resource in
      PermissionGroup(
        resource: resource, label: resourceLabels[resource] ?? spaced(resource),
        permissions: permissions[resource, default: []].sorted { $0.order < $1.order })
    }
  }

  /// Every read but check-in's, which carries the diver's insurance and emergency contact and so
  /// is never granted without being picked.
  public static func reads(_ scopes: [String]) -> [String] {
    scopes.filter { $0.hasSuffix(":read") && !$0.hasPrefix("checkin:") }
  }

  private static func spaced(_ name: String) -> String {
    name.replacingOccurrences(of: "-", with: " ")
  }

  private static let resourceLabels = [
    "certifications": "Certifications", "checkin": "Check-in", "contacts": "Contacts",
    "courses": "Courses", "dives": "Dives", "drafts": "Drafts", "export": "Exports",
    "files": "Files", "gear": "Gear", "import": "Imports", "people": "People",
    "preferences": "Preferences", "presets": "Presets", "profile": "Profile",
    "sites": "Dive sites", "species": "Species", "tags": "Tags", "trips": "Trips",
  ]

  private static let actionLabels = [
    "read": (label: "Read", order: 0), "write": (label: "Create & edit", order: 1),
    "delete": (label: "Delete", order: 2),
  ]
}
