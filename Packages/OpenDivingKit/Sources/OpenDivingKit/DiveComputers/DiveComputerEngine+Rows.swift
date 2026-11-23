import Foundation

extension DiveComputerEngine {
  /// The rows above the logbook for the account dives are kept for: every dive the walk in
  /// flight will still take, when it walks for that account, and every dive of
  /// ``divesOnPhone``.
  public func downloadRows(units: UnitSystem, phoneZone: TimeZone = .current) -> [DownloadRow] {
    var listed: [DownloadRow.Listed] = []
    if let walk, let flight = inFlight, flight.downloads.account == keeping()?.account {
      let transfer = walk.inTransfer?.fingerprint
      let computer = walk.identity?.title ?? walk.computer.title
      listed = walk.queue.map { dive in
        DownloadRow.Listed(
          uuid: walk.diveUUID(dive), fingerprint: dive.fingerprint, computer: computer,
          facts: dive.facts, watchZone: flight.watchZone, inTransfer: dive.fingerprint == transfer)
      }
    }
    return DownloadRow.rows(
      onComputer: listed, onPhone: divesOnPhone, units: units, phoneZone: phoneZone)
  }
}
