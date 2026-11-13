import Foundation
import Testing

@testable import OpenDivingKit

/// The watch over the paired computers, against a fake watcher: what is armed, when, and what a
/// completed request, Bluetooth's state, a restoration and the screen's download lead to.
@MainActor
final class DiveComputerWatchTests {
  private typealias F = DiveComputerFixtures

  private let file = FileManager.default.temporaryDirectory
    .appendingPathComponent("DiveComputerWatchTests-\(UUID().uuidString)", isDirectory: true)
    .appendingPathComponent("dive-computer-watch.log")
  private let perdix = F.perdixFound.id
  private let ocean = F.oceanFound.id
  private var records: [DiveComputerRecord] = []
  private var clock = F.moment
  private var made = 0
  private var allowed = true
  private let watcher = FakeDiveComputerWatcher()

  private func record(
    _ identity: DiveComputerIdentity, _ peripheral: UUID?, automatically: Bool = true
  ) -> DiveComputerRecord {
    var record = DiveComputerRecord(identity: identity, peripheral: peripheral)
    record.downloadsAutomatically = automatically
    return record
  }

  private func watch() -> DiveComputerWatch {
    DiveComputerWatch(
      log: DiveComputerWatchLog(file: file, now: { F.moment }),
      pairings: { [unowned self] in records },
      makeWatcher: { [unowned self] in
        guard allowed else { return nil }
        made += 1
        return watcher
      },
      now: { [unowned self] in clock })
  }

  private func lines() -> [String] {
    let text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
    return text.split(separator: "\n").map { $0.split(separator: " ", maxSplits: 1)[1] }.map(
      String.init)
  }

  @Test func aPhoneWithNothingPairedMakesNoWatcher() {
    records = [record(F.perdix, perdix, automatically: false), record(F.ocean, nil)]
    let watch = watch()
    watch.launched(.byUser)
    watch.refresh()
    #expect(made == 0)
    #expect(lines() == ["launch by the user"])
  }

  @Test func aScanMakesTheWatcherToObserveWhatIsAdvertised() {
    let watch = watch()
    watch.launched(.byUser)
    watch.scanStarted()
    #expect(made == 1)
    #expect(watcher.take() == [.start, .observe(true)])
    watch.scanStopped()
    #expect(watcher.take() == [.observe(false)])
  }

  @Test func aWatcherNotAllowedIsAskedForAgainAtTheNextRefresh() {
    records = [record(F.perdix, perdix)]
    allowed = false
    let watch = watch()
    watch.launched(.byUser)
    #expect(made == 0)
    allowed = true
    watch.refresh()
    #expect(made == 1)
  }

  @Test func eachComputerWatchedIsArmedOnceBluetoothIsOn() {
    records = [record(F.perdix, perdix), record(F.ocean, ocean)]
    let watch = watch()
    watch.launched(.byUser)
    #expect(watcher.take() == [.start])
    watcher.send(.state(.on, detail: "poweredOn"))
    #expect(Set(watcher.take()) == [.arm(perdix, after: 0), .arm(ocean, after: 0)])
    watch.refresh()
    #expect(watcher.take().isEmpty)
    #expect(lines().contains("armed Shearwater Perdix 3 \(perdix.uuidString) after 0 s"))
  }

  @Test func aCompletedRequestIsClosedAndArmedAgainAfterTheRevisitDelay() {
    records = [record(F.perdix, perdix)]
    let watch = watch()
    watch.launched(.byUser)
    watcher.send(.state(.on, detail: "poweredOn"))
    _ = watcher.take()

    watcher.send(.connected(perdix))
    #expect(watcher.take() == [.disarm(perdix)])
    // A second report of the same connection closes nothing more.
    watcher.send(.connected(perdix))
    #expect(watcher.take().isEmpty)
    clock += 2
    watcher.send(.disconnected(perdix, reason: nil))
    #expect(watcher.take() == [.arm(perdix, after: DiveComputerWatch.revisitDelay - 2)])

    // Bluetooth off drops the request; back on, it waits out what is left of the delay.
    watcher.send(.state(.off, detail: "poweredOff"))
    clock += 600
    watcher.send(.state(.on, detail: "poweredOn"))
    #expect(watcher.take() == [.arm(perdix, after: DiveComputerWatch.revisitDelay - 602)])
    clock += 600
    watcher.send(.state(.off, detail: "poweredOff"))
    watcher.send(.state(.on, detail: "poweredOn"))
    #expect(watcher.take() == [.arm(perdix, after: 0)])

    #expect(
      Array(lines().dropFirst().prefix(8)) == [
        "bluetooth poweredOn",
        "armed Shearwater Perdix 3 \(perdix.uuidString) after 0 s",
        "connected Shearwater Perdix 3 \(perdix.uuidString)",
        "closing Shearwater Perdix 3 \(perdix.uuidString), the next request after 900 s",
        "connected Shearwater Perdix 3 \(perdix.uuidString)",
        "disconnected Shearwater Perdix 3 \(perdix.uuidString)",
        "armed Shearwater Perdix 3 \(perdix.uuidString) after 898 s",
        "bluetooth poweredOff",
      ])
  }

  @Test func aResetDropsWhatWasArmedOrClosingAndArmsBothAgain() {
    records = [record(F.perdix, perdix), record(F.ocean, ocean)]
    let watch = watch()
    watch.launched(.byUser)
    watcher.send(.state(.on, detail: "poweredOn"))
    watcher.send(.connected(ocean))
    _ = watcher.take()
    watcher.send(.state(.unknown, detail: "resetting"))
    watcher.send(.state(.on, detail: "poweredOn"))
    #expect(
      Set(watcher.take()) == [
        .arm(perdix, after: 0), .arm(ocean, after: DiveComputerWatch.revisitDelay),
      ])
  }

  @Test func aFailedRequestIsArmedAgainAfterTheRevisitDelay() {
    records = [record(F.perdix, perdix)]
    let watch = watch()
    watch.launched(.byUser)
    watcher.send(.state(.on, detail: "poweredOn"))
    _ = watcher.take()
    watcher.send(.failedToConnect(perdix, reason: "Peer removed pairing information"))
    #expect(watcher.take() == [.arm(perdix, after: DiveComputerWatch.revisitDelay)])
    #expect(
      lines().contains(
        "failed to connect Shearwater Perdix 3 \(perdix.uuidString): Peer removed pairing information"
      ))
  }

  @Test func aComputerSwitchedOffOrForgottenIsWithdrawn() {
    records = [record(F.perdix, perdix)]
    let watch = watch()
    watch.launched(.byUser)
    watcher.send(.state(.on, detail: "poweredOn"))
    _ = watcher.take()
    records = [record(F.perdix, perdix, automatically: false)]
    watch.refresh()
    #expect(watcher.take() == [.disarm(perdix)])
    records = [record(F.perdix, perdix)]
    watch.refresh()
    #expect(watcher.take() == [.arm(perdix, after: 0)])
    records = []
    watch.refresh()
    #expect(watcher.take() == [.disarm(perdix)])
    #expect(lines().last == "withdrawn unpaired \(perdix.uuidString): not watched")
  }

  @Test func itYieldsToTheScreensDownloadAndVisitsAgainAfterIt() {
    records = [record(F.perdix, perdix)]
    let watch = watch()
    watch.launched(.byUser)
    watcher.send(.state(.on, detail: "poweredOn"))
    _ = watcher.take()
    watch.downloadStarted(perdix)
    #expect(watcher.take() == [.disarm(perdix)])
    watch.refresh()
    #expect(watcher.take().isEmpty)
    watch.downloadEnded(perdix)
    #expect(watcher.take() == [.arm(perdix, after: DiveComputerWatch.revisitDelay)])
    #expect(
      lines().contains(
        "withdrawn Shearwater Perdix 3 \(perdix.uuidString): a download from the screen"))
  }

  @Test func theRequestFollowsTheComputerToAnotherIdentifier() {
    records = [record(F.ocean, ocean)]
    let watch = watch()
    watch.launched(.byUser)
    watcher.send(.state(.on, detail: "poweredOn"))
    _ = watcher.take()
    let moved = UUID()
    records = [record(F.ocean, moved)]
    watch.refresh()
    #expect(watcher.take() == [.disarm(ocean), .arm(moved, after: 0)])
    #expect(
      lines().contains("moved Suunto Ocean from \(ocean.uuidString) to \(moved.uuidString)"))
  }

  @Test func aPeripheralNotFoundIsNotAskedForAgainUntilBluetoothReturns() {
    records = [record(F.perdix, perdix)]
    let watch = watch()
    watch.launched(.byUser)
    watcher.send(.state(.on, detail: "poweredOn"))
    watcher.send(.notFound(perdix))
    _ = watcher.take()
    watch.refresh()
    #expect(watcher.take().isEmpty)
    watcher.send(.state(.off, detail: "poweredOff"))
    watcher.send(.state(.on, detail: "poweredOn"))
    #expect(watcher.take() == [.arm(perdix, after: 0)])
  }

  @Test func whatIOSRestoredIsKeptClosedOrWithdrawn() {
    let orphan = UUID()
    records = [record(F.perdix, perdix), record(F.ocean, ocean)]
    let watch = watch()
    watch.launched(.byIOS(restoring: ["app.opendiving.dive-computer-watch"]))
    watcher.send(.restored(perdix, .pending))
    watcher.send(.restored(ocean, .connected))
    watcher.send(.restored(orphan, .pending))
    _ = watcher.take()
    watcher.send(.state(.on, detail: "poweredOn"))
    // The pending request stands; the connection is closed; the unpaired one is withdrawn.
    #expect(Set(watcher.take()) == [.disarm(ocean), .disarm(orphan)])
    // The connection iOS delivers after the restoration is the same one.
    watcher.send(.connected(ocean))
    #expect(watcher.take().isEmpty)
    #expect(lines().first == "launch by iOS, restoring app.opendiving.dive-computer-watch")
    #expect(lines().contains("restored Suunto Ocean \(ocean.uuidString), request connected"))
  }

  @Test func aLaunchByIOSWithNothingPairedWithdrawsWhatItRestored() {
    let watch = watch()
    watch.launched(.byIOS(restoring: ["app.opendiving.dive-computer-watch"]))
    #expect(made == 1)
    watcher.send(.restored(perdix, .pending))
    watcher.send(.state(.on, detail: "poweredOn"))
    #expect(watcher.take() == [.start, .disarm(perdix)])
  }

  @Test func eachDiveComputerAdvertisingIsLoggedOncePerScan() {
    records = [record(F.perdix, perdix)]
    let watch = watch()
    watch.launched(.byUser)
    let paired = DiveComputerAdvertisement(
      peripheral: perdix, name: "Perdix 3", family: nil, services: [],
      companyIdentifier: 0x0009, connectable: true)
    let unpaired = DiveComputerAdvertisement(
      peripheral: ocean, name: "Suunto Ocean 253810000400", family: .suuntoNautic,
      services: ["61353090-8231-49CC-B57A-886370740041"], companyIdentifier: nil,
      connectable: nil)
    let headphones = DiveComputerAdvertisement(
      peripheral: UUID(), name: "Headphones", family: nil, services: [], companyIdentifier: 0x004C,
      connectable: true)
    // Nothing is logged outside a scan.
    watcher.send(.advertised(paired))
    watch.scanStarted()
    for advertisement in [paired, unpaired, headphones, paired] {
      watcher.send(.advertised(advertisement))
    }
    watch.scanStopped()
    watch.scanStarted()
    watcher.send(.advertised(paired))
    let logged = lines().filter { $0.hasPrefix("advertises") }
    #expect(
      logged == [
        "advertises \"Perdix 3\", Shearwater Perdix 3 \(perdix.uuidString), services none, company 0x0009, connectable yes",
        "advertises \"Suunto Ocean 253810000400\", unpaired \(ocean.uuidString), services 61353090-8231-49CC-B57A-886370740041, company none, connectable unknown",
        "advertises \"Perdix 3\", Shearwater Perdix 3 \(perdix.uuidString), services none, company 0x0009, connectable yes",
      ])
  }
}
