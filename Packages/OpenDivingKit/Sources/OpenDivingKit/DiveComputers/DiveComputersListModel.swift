import Foundation
import Observation

/// Settings' *Dive computers* list: the computers the account has downloaded from, each with
/// *Forget this dive computer*, *Download all dives next time* and, for a family that logs
/// instants, the zone its dives are written in. Forgetting removes the phone's record and
/// nothing on the server.
@MainActor
@Observable
public final class DiveComputersListModel {
  public private(set) var computers: [DiveComputerRecord] = []
  /// Why the last change was not kept.
  public private(set) var error: String?

  @ObservationIgnored private let session: Session
  @ObservationIgnored private let zone: TimeZone

  /// `zone` is the phone's, which the *Last downloaded* day is printed in.
  public init(session: Session, zone: TimeZone = .current) {
    self.session = session
    self.zone = zone
    reload()
  }

  /// The account's records: the loaded account's, or the last account's while it is unknown.
  public func reload() {
    computers = store?.records() ?? []
  }

  /// *Serial D9772626 · Last downloaded 12 October*.
  public func subtitle(_ record: DiveComputerRecord) -> String? {
    DiveComputerText.subtitle(
      serial: record.serial, lastDownloaded: record.lastDownloaded, in: zone)
  }

  public func forget(_ record: DiveComputerRecord) {
    store?.forget(record)
    reload()
  }

  /// *Download all dives next time*: the next download from it sets no fingerprint.
  public func downloadAllNextTime(_ record: DiveComputerRecord) {
    update(record) { $0.downloadAllNextTime = true }
  }

  /// Sets the diver's zone for the computer's dives, which wins over the watch's; nil clears it
  /// and the watch's applies again.
  public func setDiverZone(_ zone: TimeZone?, for record: DiveComputerRecord) {
    update(record) { $0.diverZone = zone }
  }

  private func update(_ record: DiveComputerRecord, _ change: (inout DiveComputerRecord) -> Void) {
    guard let store, var current = store.record(family: record.family, serial: record.serial)
    else { return }
    change(&current)
    do {
      try store.save(current)
      error = nil
    } catch {
      self.error = "The change could not be kept on this phone: \(error)."
    }
    reload()
  }

  private var store: DiveComputerStore? {
    guard let origin = session.state.origin else { return nil }
    if case .signedIn = session.state, session.accountLoaded, let user = session.user {
      return DiveComputerStore(store: session.store, origin: origin, account: user.uuid)
    }
    return session.store.lastAccount(for: origin).map {
      DiveComputerStore(store: session.store, origin: origin, account: $0)
    }
  }
}
