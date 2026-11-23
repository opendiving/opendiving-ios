import Foundation

/// What the logbook holds of a walk's list: the server is asked, once in a walk, which of the
/// dives the computer lists its logbook already holds, and whether each holding dive keeps the
/// computer's original download. Before its first transfer the walk leaves out those held with
/// it, and takes those held without it after the rest. The server compares by its own import's
/// rule, so the phone sends what the computer lists and compares nothing itself.
extension DiveComputerEngine {
  /// How long the walk waits for the server's answer before it goes on without one.
  static let knownDivesWait: TimeInterval = 10

  /// The listed dives the logbook of `account` holds, by fingerprint, each with the server's row.
  /// With no route, no loaded account, a walk kept before the load, no listed start to send, a
  /// server without the route, a refusal, or no answer within ``knownDivesWait``: nil, and the
  /// walk leaves out only what the phone need not take. A list past ``KnownDivesQuery/maxDives``
  /// is asked in parts.
  func heldByLogbook(
    _ identity: DiveComputerIdentity, _ listed: [DiveComputerListing.Download], account: UUID,
    marked: Bool
  ) async -> [Data: KnownDive]? {
    guard !marked, !identity.serial.isEmpty, case .signedIn = session.state, session.accountLoaded,
      session.user?.uuid == account, session.connectivity.isRouteAvailable,
      let client = try? session.requireClient()
    else { return nil }
    var fingerprints: [UUID: Data] = [:]
    var rows: [KnownDivesQuery.Dive] = []
    for dive in listed {
      guard let start = dive.facts.listedStart else { continue }
      let uuid = DiveComputerArchive.diveUUID(identity, fingerprint: dive.fingerprint)
      guard fingerprints.updateValue(dive.fingerprint, forKey: uuid) == nil else { continue }
      rows.append(KnownDivesQuery.Dive(uuid: uuid, startedAt: start))
    }
    guard !rows.isEmpty else { return nil }
    let queries = stride(from: 0, to: rows.count, by: KnownDivesQuery.maxDives).map {
      KnownDivesQuery(
        serial: identity.serial,
        dives: Array(rows[$0..<min($0 + KnownDivesQuery.maxDives, rows.count)]))
    }
    let deadline = now().addingTimeInterval(Self.knownDivesWait)
    let sleep = sleep
    let known = await withTaskGroup(of: [KnownDive]?.self) { group in
      group.addTask {
        var known: [KnownDive] = []
        for query in queries {
          guard let answer = try? await client.knownDives(query) else { return nil }
          known += answer
        }
        return known
      }
      group.addTask {
        try? await sleep(deadline)
        return nil
      }
      let first = await group.next() ?? nil
      group.cancelAll()
      return first
    }
    return known.map { rows in
      Dictionary(
        rows.compactMap { row in fingerprints[row.uuid].map { ($0, row) } },
        uniquingKeysWith: { first, _ in first })
    }
  }
}
