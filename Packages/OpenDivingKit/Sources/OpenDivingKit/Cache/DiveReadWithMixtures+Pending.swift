import Foundation

extension DiveReadWithMixtures {
  /// The dive with queued updates laid over it, in order: what the detail shows and the edit
  /// form starts from while the edit waits for the server.
  ///
  /// A member the update sets replaces the dive's. A list of references takes its names from
  /// the dive itself, then from what the phone has cached — the lookups, the life list, the
  /// records it has created — and leaves out an entry it cannot name. A trip, a course or a
  /// dive centre the phone created and the server has not named shows as none until it does.
  /// Nil when the result cannot be read back, which never happens to an update this build
  /// wrote.
  func applying(_ updates: [DiveUpdate], tables: LookupTables) -> DiveReadWithMixtures? {
    guard !updates.isEmpty else { return self }
    let encoder = APICoding.encoder()
    guard let data = try? encoder.encode(self),
      var dive = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    else { return nil }
    let known = Known(dive: self, tables: tables, encoder: encoder)
    for update in updates {
      guard let data = try? encoder.encode(update),
        let changes = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
      else { return nil }
      for (key, value) in changes {
        switch key {
        case "trip_uuid", "course_uuid", "contact_uuid":
          let local = (value as? String)?.hasPrefix(RecordRef.localPrefix) ?? false
          dive[key] = local ? NSNull() : value
        case "dive_site_uuids":
          dive["dive_sites"] = (value as? [String] ?? []).compactMap { known.sites[$0] }
        case "gear_item_uuids":
          dive["gear_items"] = (value as? [String] ?? []).compactMap { known.gear[$0] }
        case "mixtures":
          dive["mixtures"] = (value as? [[String: Any]] ?? []).enumerated().map {
            index, mixture -> [String: Any] in
            var read = mixture
            read["id"] = -(index + 1)
            let gear = (mixture["gear_item_uuid"] as? String).flatMap { known.gear[$0] }
            read["gear_item"] = gear ?? NSNull()
            read["gear_item_uuid"] = nil
            return read
          }
        case "sightings":
          dive["sightings"] = (value as? [[String: Any]] ?? []).compactMap { sighting -> [String: Any]? in
            guard let species = sighting["species_uuid"] as? String,
              var read = known.species[species]
            else { return nil }
            read["count"] = sighting["count"] ?? NSNull()
            read["abundance"] = sighting["abundance"] ?? NSNull()
            read["notes"] = sighting["notes"] ?? ""
            return read
          }
        default:
          dive[key] = value
        }
      }
    }
    guard let merged = try? JSONSerialization.data(withJSONObject: dive) else { return nil }
    return try? APICoding.decoder().decode(DiveReadWithMixtures.self, from: merged)
  }
}

/// The names a reference can be given, by its spelling on the wire, as JSON objects.
private struct Known {
  var sites: [String: Any] = [:]
  var gear: [String: Any] = [:]
  var species: [String: [String: Any]] = [:]

  init(dive: DiveReadWithMixtures, tables: LookupTables, encoder: JSONEncoder) {
    func object(_ value: some Encodable) -> [String: Any]? {
      guard let data = try? encoder.encode(value) else { return nil }
      return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
    func key(_ ref: RecordRef) -> String? {
      let uuid = ref.uuid.uuidString.lowercased()
      return ref.isLocal ? RecordRef.localPrefix + uuid : uuid
    }
    for row in tables.diveSites {
      let site = DiveSiteInfo(ref: row.ref, name: row.name, location: row.location)
      if let key = key(row.ref) { sites[key] = object(site) }
    }
    for site in dive.diveSites {
      if let key = key(site.ref) { sites[key] = object(site) }
    }
    var items = tables.knownGear
    for item in dive.gearItems + dive.mixtures.compactMap(\.gearItem) { items[item.ref] = item }
    for (ref, item) in items {
      if let key = key(ref) { gear[key] = object(item) }
    }
    for entry in tables.lifeList {
      species[entry.uuid.uuidString.lowercased()] = [
        "uuid": entry.uuid.uuidString.lowercased(), "scientific_name": entry.scientificName,
        "common_name": entry.commonName ?? NSNull(), "rank": entry.rank,
        "photo_sha256": entry.photoSha256 ?? NSNull(),
      ]
    }
    for sighting in dive.sightings {
      species[sighting.uuid.uuidString.lowercased()] = object(sighting)
    }
  }
}
