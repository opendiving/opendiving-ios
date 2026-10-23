/// The registries DiveJSON names for a site's or a species' `external_ids`, each with the
/// identifier form its schema holds it to and the page that identifier opens. A registry
/// outside them is shown as written and links nowhere.
public enum ExternalIdRegistry: String, Sendable, Hashable, CaseIterable {
  case openStreetMap = "openstreetmap"
  case wikidata
  case worms

  /// The registry as a reader knows it — `OpenStreetMap` — or as written where the
  /// format names no such registry.
  public static func label(_ registry: String) -> String {
    ExternalIdRegistry(rawValue: registry)?.label ?? registry
  }

  /// The registry's own page for the entry, or nil for a registry the format does not
  /// name or an identifier not of its registry's form: a link built from one would lead
  /// nowhere a reader could trust.
  public static func link(registry: String, identifier: String) -> String? {
    guard let known = ExternalIdRegistry(rawValue: registry), known.accepts(identifier)
    else { return nil }
    return known.linkPrefix + identifier
  }

  public var label: String {
    switch self {
    case .openStreetMap: "OpenStreetMap"
    case .wikidata: "Wikidata"
    case .worms: "WoRMS"
    }
  }

  private var linkPrefix: String {
    switch self {
    case .openStreetMap: "https://www.openstreetmap.org/"
    case .wikidata: "https://www.wikidata.org/wiki/"
    case .worms: "https://www.marinespecies.org/aphia.php?p=taxdetails&id="
    }
  }

  /// `node|way|relation/<n>`, `Q<n>` and `<n>`, each `n` a positive integer with no
  /// leading zero.
  private func accepts(_ identifier: String) -> Bool {
    switch self {
    case .openStreetMap:
      let parts = identifier.split(separator: "/", omittingEmptySubsequences: false)
      return parts.count == 2 && ["node", "way", "relation"].contains(parts[0])
        && Self.isPositiveInteger(parts[1])
    case .wikidata:
      return identifier.first == "Q" && Self.isPositiveInteger(identifier.dropFirst())
    case .worms:
      return Self.isPositiveInteger(Substring(identifier))
    }
  }

  private static func isPositiveInteger(_ text: Substring) -> Bool {
    guard let first = text.first, first != "0" else { return false }
    return text.allSatisfy { $0.isASCII && $0.isNumber }
  }
}
