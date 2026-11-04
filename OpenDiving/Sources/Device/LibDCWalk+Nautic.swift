@preconcurrency import Clibdivecomputer
import Foundation
@preconcurrency import LibDCSwift
import OpenDivingKit

/// A Suunto Nautic-family watch, walked by id: the identity, the zone, a wait while the watch says
/// it is busy, the logbook listed, each entry's sport learned from its summary — or from the
/// record, where an earlier walk kept it — and counted, then each new entry downloaded by id
/// unless its summary names a sport that is no dive or its dive already waits in the import
/// screen. Which entries are summarised, counted and downloaded is ``NauticSelection``'s.
///
/// Another app, such as the Suunto app, can share the link. A summary, the descriptors or a
/// download that another app's handshake broke, which the watch's busy state does not show, is
/// waited out and tried again on the same connection for as long as it takes. Every other transfer
/// that fails, but on a cancel or a lost link, asks the watch whether it is busy, and while it is,
/// waits and tries the same transfer again
/// (``nauticNext(_:status:otherApp:busy:freeFailures:reconnects:)``). One that times out while the
/// watch says free closes the device, opens it again and carries on from that transfer
/// (``reconnect()``), the dive's received bytes kept in the resume buffer; each transfer is a line
/// in the download's log.
nonisolated extension LibDCWalk {
  func walkNautic(serial: String) -> DiveComputerDownloadEnd {
    var firmware = nauticFirmware()
    let identity = identify(serial: serial, firmware: firmware)
    let record = lookup(family, serial)
    let fingerprint = record?.fingerprintToSet
    let zoneRead = readWatchZone()

    // A busy watch can refuse the firmware or the zone, and a reopened link may answer what the
    // first did not; once the watch is free they are read again.
    var readAgain = false
    asking: while true {
      switch busyWait() {
      case .stop(let status): return nauticEnd(status)
      case .free: break asking
      case .waited:
        readAgain = true
        break asking
      case .reconnected: readAgain = true
      }
    }
    if readAgain {
      if firmware == nil {
        firmware = nauticFirmware()
        identify(serial: serial, firmware: firmware)
      }
      if !zoneRead { readWatchZone() }
    }

    let list: Data
    switch fetchWhileBusy(.listing, "listing", { suunto_nautic_device_list($0, $1) }) {
    case .answered(let bytes): list = bytes
    case .failed(let status), .stop(let status): return nauticEnd(status)
    }
    let ids = Self.nauticIDs(list)

    var learned: [UInt32: NauticSelection.Summary] = [:]
    var descriptors: NauticDescriptors?
    var descriptorsRead = false
    for id in NauticSelection.summariesNeeded(ids: ids, remembered: record?.nauticSports) {
      let fetched = fetchWhileBusy(.summary, "summary \(Self.entryLabel(id))") {
        suunto_nautic_device_download_summary($0, String(id), $1)
      }
      switch fetched {
      case .stop(let stopped): return nauticEnd(stopped)
      case .failed: learned[id] = .unread
      case .answered(let summary) where summary.isEmpty: learned[id] = .empty
      case .answered(let summary):
        // One entry's descriptors serve the walk: a summary another firmware laid out does not
        // fit them and decodes to no sport.
        if !descriptorsRead {
          descriptorsRead = true
          let fetched = fetchWhileBusy(.summary, "descriptors \(Self.entryLabel(id))") {
            suunto_nautic_device_fetch_paged($0, NauticDescriptors.path(id), $1)
          }
          switch fetched {
          case .stop(let stopped): return nauticEnd(stopped)
          case .answered(let bytes) where !bytes.isEmpty:
            let read = NauticDescriptors(bytes)
            descriptors = read
            identify(serial: serial, firmware: firmware, hardware: read.hardware)
          case .answered, .failed: break
          }
        }
        learned[id] = descriptors.map { .read(sport: $0.sport(inSummary: summary)) } ?? .unread
      }
    }

    let selection = NauticSelection(
      ids: ids, fingerprint: fingerprint, remembered: record?.nauticSports, learned: learned
    ) { waiting(identity, NauticSelection.fingerprint($0)) }
    events.yield(.listing(selection.listing))

    for entry in selection.entries {
      if cancel.isSet { break }
      let mark = NauticSelection.fingerprint(entry.id)
      switch entry.fate {
      case .skip:
        events.yield(.skipped(fingerprint: mark))
        continue
      case .waiting:
        waitingSkipped += 1
        events.yield(.skipped(fingerprint: mark))
        continue
      case .download: break
      }
      let fetched = fetchWhileBusy(
        .download(counted: entry.counted), "download \(Self.entryLabel(entry.id))"
      ) { suunto_nautic_device_download($0, String(entry.id), $1) }
      switch fetched {
      case .stop(let stopped): return nauticEnd(stopped)
      case .failed:
        // The same failure on every attempt: left out, so the dives behind it are still taken.
        notDownloaded += 1
        events.yield(.skipped(fingerprint: mark))
      // Success with no bytes, which an entry listed with size 0 gives: passed over, yielding
      // nothing, so the fingerprint is moved only by an entry delivered or skipped.
      case .answered(let bytes) where bytes.isEmpty: break
      case .answered(let bytes):
        guard dive(bytes, fingerprint: mark) else { return nauticEnd(DC_STATUS_CANCELLED) }
      }
    }
    return nauticEnd(DC_STATUS_SUCCESS)
  }

  /// `/Info`'s firmware, spelled as the family's exports spell it; nil where it did not read.
  private func nauticFirmware() -> String? {
    guard let handle = device?.pointee.device else { return nil }
    let (_, info) = Self.buffered { suunto_nautic_device_fetch(handle, NauticInfo.path, $0) }
    return NauticInfo.firmware(info).flatMap { LibDCNames.firmware($0, family: family) }
  }

  /// The ids `suunto_nautic_device_list` packs, four little-endian bytes each, newest first.
  static func nauticIDs(_ list: Data) -> [UInt32] {
    let bytes = [UInt8](list)
    var ids: [UInt32] = []
    var offset = 0
    while offset + 4 <= bytes.count {
      var id: UInt32 = 0
      for index in (offset..<(offset + 4)).reversed() {
        id = id << 8 | UInt32(bytes[index])
      }
      ids.append(id)
      offset += 4
    }
    return ids
  }

  /// An entry's id, which is its start as a Unix time, and that start, for the log.
  static func entryLabel(_ id: UInt32) -> String {
    "\(id) (\(Date(timeIntervalSince1970: TimeInterval(id)).ISO8601Format()))"
  }

  /// A transfer the walk makes, which decides what its failure costs.
  enum NauticFetch: Equatable {
    case listing
    /// An entry's summary, or the descriptors it decodes against.
    case summary
    /// An entry's profile by id; `counted` where the listing counts it as a dive.
    case download(counted: Bool)
  }

  /// What the walk does after one attempt at a transfer.
  enum NauticNext: Equatable {
    /// It answered: the bytes are the transfer's.
    case take
    /// Another app's handshake broke it: wait ``otherAppWait`` and try it again on the same
    /// connection.
    case awaitOtherApp
    /// It failed in a way a busy watch may explain: ask whether it is busy, waiting while it is.
    case readBusy
    /// Try the same transfer again.
    case retry
    /// Close the device, open it again and try the same transfer on it.
    case reconnect
    /// Give it up and go on: a summary reads as unread, a download leaves its entry out.
    case passOver
    /// The walk ends on this status.
    case stop(dc_status_t)
  }

  /// The attempts a counted entry's download gets while the watch says it is free.
  static let nauticDownloadAttempts = 3

  /// The seconds a transfer another app's handshake broke is waited out before it is tried again.
  static let otherAppWait = 10

  /// After one attempt that answered `status`: `otherApp` is whether another app's handshake broke
  /// it, `busy` is nil until the watch was asked, then whether it said busy, `freeFailures` counts
  /// the attempts, this one included, that failed while it said free, across reopens, and
  /// `reconnects` the reopens the walk has made. A cancel or a lost link stops the walk at once. A
  /// summary, the descriptors or a download another app broke is waited out and tried again without
  /// asking or counting, however often: the walk cannot tell when that app lets go. A failure while
  /// busy is waited out and tried again without counting. While free, a timeout reopens the device,
  /// at once, while the walk has reopens left (``reconnects(after:made:)``). Otherwise the listing
  /// stops the walk, and a summary or the descriptors read as unread; a counted download is tried
  /// until ``nauticDownloadAttempts`` have failed, an uncounted one once, and then a timeout, which
  /// a later connection can cure, stops the walk without moving the fingerprint past it, while any
  /// other failure, which repeats, leaves the entry out.
  static func nauticNext(
    _ fetch: NauticFetch, status: dc_status_t, otherApp: Bool, busy: Bool?, freeFailures: Int,
    reconnects: Int
  ) -> NauticNext {
    switch status {
    case DC_STATUS_SUCCESS: return .take
    case DC_STATUS_CANCELLED, DC_STATUS_IO, DC_STATUS_NODEVICE: return .stop(status)
    default: break
    }
    if otherApp, fetch != .listing { return .awaitOtherApp }
    guard let busy else { return .readBusy }
    if busy { return .retry }
    if Self.reconnects(after: status, made: reconnects) { return .reconnect }
    switch fetch {
    case .listing: return .stop(status)
    case .summary: return .passOver
    case .download(let counted):
      if freeFailures < (counted ? nauticDownloadAttempts : 1) { return .retry }
      return status == DC_STATUS_TIMEOUT ? .stop(status) : .passOver
    }
  }

  private enum NauticFetched {
    case answered(Data)
    /// Given up, its last status.
    case failed(dc_status_t)
    case stop(dc_status_t)
  }

  /// One transfer over the open device's handle and a fresh buffer, tried again as
  /// ``nauticNext(_:status:otherApp:busy:freeFailures:reconnects:)`` says, each attempt logged
  /// under `label`.
  private func fetchWhileBusy(
    _ fetch: NauticFetch, _ label: String,
    _ call: (_ handle: OpaquePointer, _ buffer: OpaquePointer) -> dc_status_t
  ) -> NauticFetched {
    var freeFailures = 0
    while true {
      if cancel.isSet { return .stop(DC_STATUS_CANCELLED) }
      guard let handle = device?.pointee.device else { return .stop(DC_STATUS_NODEVICE) }
      let began = Date.now
      let ((status, bytes), otherApp) = session.watchingOtherApp {
        Self.buffered { call(handle, $0) }
      }
      log(
        "\(label) \(LibDCNames.status(status)) \(bytes.count) bytes "
          + "\(LibDCDeviceSession.milliseconds(since: began)) ms")
      var next = Self.nauticNext(
        fetch, status: status, otherApp: otherApp, busy: nil, freeFailures: freeFailures,
        reconnects: reconnects)
      if next == .readBusy {
        let busy: Bool
        switch busyWait() {
        case .stop(let stopped): return .stop(stopped)
        // The busy read reopened the device: the transfer is tried on it, uncounted.
        case .reconnected: continue
        case .waited: busy = true
        case .free:
          busy = false
          freeFailures += 1
        }
        next = Self.nauticNext(
          fetch, status: status, otherApp: otherApp, busy: busy, freeFailures: freeFailures,
          reconnects: reconnects)
      }
      switch next {
      case .take: return .answered(bytes)
      case .awaitOtherApp:
        events.yield(.busy(.otherApp))
        log("\(label) broken by another app, waiting \(Self.otherAppWait) s")
        for _ in 0..<(Self.otherAppWait * 10) {
          if cancel.isSet { return .stop(DC_STATUS_CANCELLED) }
          usleep(100_000)
        }
      case .retry: continue
      case .reconnect:
        if let stopped = reconnect() { return .stop(stopped) }
      case .passOver: return .failed(status)
      case .stop(let stopped): return .stop(stopped)
      case .readBusy: return .stop(status)
      }
    }
  }

  private enum BusyWait {
    /// The watch said it is free, or has no such resource.
    case free
    /// It said it was busy, and has since said it is free.
    case waited
    /// Its subscribe or unsubscribe timed out, and the device was opened again.
    case reconnected
    case stop(dc_status_t)
  }

  /// Asks the watch whether it is busy with another app and, while it is, waits in waits of a
  /// second so a cancel ends it at the next. A watch with no such resource, or that refuses it,
  /// is not waited for. Subscribed and unsubscribed between transfers, since a subscription is
  /// not valid while a download runs; an unsubscribe that fails ends the walk. Either that times
  /// out reopens the device while the walk has reopens left.
  private func busyWait() -> BusyWait {
    guard let handle = device?.pointee.device else { return .stop(DC_STATUS_NODEVICE) }
    let began = Date.now
    let subscription: SuuntoNauticExplorer.Subscription
    do {
      subscription = try SuuntoNauticExplorer.subscribe(dcDevice: handle, path: Self.busyStatePath)
    } catch {
      let status = Self.explorerStatus(error)
      log(
        "busy read \(LibDCNames.status(status)) \(LibDCDeviceSession.milliseconds(since: began)) ms"
      )
      guard Self.reconnects(after: status, made: reconnects) else { return .free }
      return reconnect().map { .stop($0) } ?? .reconnected
    }
    let busy = Self.isBusy(subscription.initialValue)
    log(
      "busy read \(busy ? "busy" : "free") \(LibDCDeviceSession.milliseconds(since: began)) ms")
    let stopped = busy ? waitForFree(handle, subscription) : nil
    if busy, stopped == nil {
      log("busy wait free after \(LibDCDeviceSession.milliseconds(since: began)) ms")
    }
    do {
      try SuuntoNauticExplorer.unsubscribe(dcDevice: handle, subscription)
    } catch {
      let status = Self.explorerStatus(error)
      log("busy unsubscribe \(LibDCNames.status(status))")
      if let stopped { return .stop(stopped) }
      guard Self.reconnects(after: status, made: reconnects) else { return .stop(status) }
      return reconnect().map { .stop($0) } ?? .reconnected
    }
    if let stopped { return .stop(stopped) }
    return busy ? .waited : .free
  }

  /// The status an explorer call failed on; a failure that names none reads as a lost link.
  private static func explorerStatus(_ error: any Error) -> dc_status_t {
    if case SuuntoNauticExplorer.ExplorerError.requestFailed(let status) = error { return status }
    return DC_STATUS_IO
  }

  /// Yields the busy event, waits for the watch to push free and yields it; nil once free, or
  /// the status that ended the wait.
  private func waitForFree(
    _ handle: OpaquePointer, _ subscription: SuuntoNauticExplorer.Subscription
  ) -> dc_status_t? {
    events.yield(.busy(.reported))
    while true {
      if cancel.isSet { return DC_STATUS_CANCELLED }
      let pushed: SuuntoNauticExplorer.Notification?
      do {
        pushed = try SuuntoNauticExplorer.waitForNotification(dcDevice: handle, timeoutMs: 1000)
      } catch SuuntoNauticExplorer.ExplorerError.requestFailed(let status) {
        return status
      } catch {
        return DC_STATUS_IO
      }
      if let pushed, subscription.matches(pushed.handle), !Self.isBusy(pushed.value) { break }
    }
    events.yield(.busy(.free))
    return nil
  }

  static let busyStatePath = "/Sync/BusyState"

  /// Busy where the value is a non-zero integer, as libdc-swift's own sync reads it.
  static func isBusy(_ value: SuuntoNauticExplorer.WhiteboardValue?) -> Bool {
    (value?.integerValue ?? 0) != 0
  }

  private func nauticEnd(_ status: dc_status_t) -> DiveComputerDownloadEnd {
    Self.end(
      status: status, cancelled: cancel.isSet, family: family, delivered: delivered,
      emptyReads: emptyReads, refused: refused, fingerprintSet: false, waiting: waitingSkipped,
      notDownloaded: notDownloaded)
  }
}
