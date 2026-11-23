import Foundation

/// What the logbook holds of a walk's list: the server is asked, once in a walk, which of the
/// dives the walk would otherwise take its logbook already holds, and the walk leaves those out
/// before its first transfer. The server compares by its own import's rule, so the phone sends
/// what the computer lists and compares nothing itself.
extension DiveComputerEngine {
  /// How long the walk waits for the server's answer before it goes on without one.
  static let knownDivesWait: TimeInterval = 10

  /// The fingerprints of the listed dives the logbook of `account` holds. With no route, no
  /// loaded account, a walk kept before the load, a server without the route, a refusal, or no
  /// answer within ``knownDivesWait``: none, and the walk takes what it takes today. A list past
  /// ``KnownDivesQuery/maxDives`` is asked in parts.
  func heldByLogbook(
    _ identity: DiveComputerIdentity, _ listed: [DiveComputerListing.Download], account: UUID,
    marked: Bool
  ) async -> Set<Data> {
    guard !marked, !identity.serial.isEmpty, case .signedIn = session.state, session.accountLoaded,
      session.user?.uuid == account, session.connectivity.isRouteAvailable,
      let client = try? session.requireClient()
    else { return [] }
    var fingerprints: [UUID: Data] = [:]
    var rows: [KnownDivesQuery.Dive] = []
    for dive in listed {
      guard let start = dive.facts.listedStart else { continue }
      let uuid = DiveComputerArchive.diveUUID(identity, fingerprint: dive.fingerprint)
      guard fingerprints.updateValue(dive.fingerprint, forKey: uuid) == nil else { continue }
      rows.append(KnownDivesQuery.Dive(uuid: uuid, startedAt: start))
    }
    guard !rows.isEmpty else { return [] }
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
    return Set((known ?? []).compactMap { fingerprints[$0.uuid] })
  }
}
