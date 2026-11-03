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
/// Every transfer that fails, but on a cancel or a lost link, asks the watch whether it is busy
/// with another app — the Suunto app shares the link — and while it is, waits and tries the same
/// transfer again (``nauticNext(_:status:busy:freeFailures:)``).
nonisolated extension LibDCWalk {
  func walkNautic(_ handle: OpaquePointer, serial: String) -> DiveComputerDownloadEnd {
    var firmware = nauticFirmware(handle)
    let identity = identify(serial: serial, firmware: firmware)
    let record = lookup(family, serial)
    let fingerprint = record?.fingerprintToSet
    let zoneRead = readWatchZone()

    // A busy watch can refuse the firmware or the zone; once it is free they are read again.
    switch busyWait(handle) {
    case .stop(let status): return nauticEnd(status)
    case .free: break
    case .waited:
      if firmware == nil {
        firmware = nauticFirmware(handle)
        identify(serial: serial, firmware: firmware)
      }
      if !zoneRead { readWatchZone() }
    }

    let list: Data
    switch fetchWhileBusy(handle, .listing, { suunto_nautic_device_list(handle, $0) }) {
    case .answered(let bytes): list = bytes
    case .failed(let status), .stop(let status): return nauticEnd(status)
    }
    let ids = Self.nauticIDs(list)

    var learned: [UInt32: NauticSelection.Summary] = [:]
    var descriptors: NauticDescriptors?
    var descriptorsRead = false
    for id in NauticSelection.summariesNeeded(ids: ids, remembered: record?.nauticSports) {
      let fetched = fetchWhileBusy(handle, .summary) {
        suunto_nautic_device_download_summary(handle, String(id), $0)
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
          let fetched = fetchWhileBusy(handle, .summary) {
            suunto_nautic_device_fetch_paged(handle, NauticDescriptors.path(id), $0)
          }
          switch fetched {
          case .stop(let stopped): return nauticEnd(stopped)
          case .answered(let bytes) where !bytes.isEmpty: descriptors = NauticDescriptors(bytes)
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
      let fetched = fetchWhileBusy(handle, .download(counted: entry.counted)) {
        suunto_nautic_device_download(handle, String(entry.id), $0)
      }
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
  private func nauticFirmware(_ handle: OpaquePointer) -> String? {
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
    /// It failed in a way a busy watch may explain: ask whether it is busy, waiting while it is.
    case readBusy
    /// Try the same transfer again.
    case retry
    /// Give it up and go on: a summary reads as unread, a download leaves its entry out.
    case passOver
    /// The walk ends on this status.
    case stop(dc_status_t)
  }

  /// The attempts a counted entry's download gets while the watch says it is free.
  static let nauticDownloadAttempts = 3

  /// After one attempt that answered `status`: `busy` is nil until the watch was asked, then
  /// whether it said busy, and `freeFailures` counts the attempts, this one included, that failed
  /// while it said free. A cancel or a lost link stops the walk at once. A failure while busy is
  /// waited out and tried again without counting. While free, the listing stops the walk, and a
  /// summary or the descriptors read as unread; a counted download is tried until
  /// ``nauticDownloadAttempts`` have failed, an uncounted one once, and then a stall
  /// (`DC_STATUS_TIMEOUT`), which a later connection can cure, stops the walk without moving the
  /// fingerprint past it, while any other failure, which repeats, leaves the entry out.
  static func nauticNext(_ fetch: NauticFetch, status: dc_status_t, busy: Bool?, freeFailures: Int)
    -> NauticNext
  {
    switch status {
    case DC_STATUS_SUCCESS: return .take
    case DC_STATUS_CANCELLED, DC_STATUS_IO, DC_STATUS_NODEVICE: return .stop(status)
    default: break
    }
    guard let busy else { return .readBusy }
    if busy { return .retry }
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

  /// One transfer, tried again as ``nauticNext(_:status:busy:freeFailures:)`` says.
  private func fetchWhileBusy(
    _ handle: OpaquePointer, _ fetch: NauticFetch, _ call: (OpaquePointer) -> dc_status_t
  ) -> NauticFetched {
    var freeFailures = 0
    while true {
      if cancel.isSet { return .stop(DC_STATUS_CANCELLED) }
      let (status, bytes) = Self.buffered(call)
      var next = Self.nauticNext(fetch, status: status, busy: nil, freeFailures: freeFailures)
      if next == .readBusy {
        let busy: Bool
        switch busyWait(handle) {
        case .stop(let stopped): return .stop(stopped)
        case .waited: busy = true
        case .free:
          busy = false
          freeFailures += 1
        }
        next = Self.nauticNext(fetch, status: status, busy: busy, freeFailures: freeFailures)
      }
      switch next {
      case .take: return .answered(bytes)
      case .retry: continue
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
    case stop(dc_status_t)
  }

  /// Asks the watch whether it is busy with another app and, while it is, waits in waits of a
  /// second so a cancel ends it at the next. A watch with no such resource, or that refuses it,
  /// is not waited for. Subscribed and unsubscribed between transfers, since a subscription is
  /// not valid while a download runs; an unsubscribe that fails ends the walk.
  private func busyWait(_ handle: OpaquePointer) -> BusyWait {
    guard
      let subscription = try? SuuntoNauticExplorer.subscribe(
        dcDevice: handle, path: Self.busyStatePath)
    else { return .free }
    let busy = Self.isBusy(subscription.initialValue)
    let stopped = busy ? waitForFree(handle, subscription) : nil
    do {
      try SuuntoNauticExplorer.unsubscribe(dcDevice: handle, subscription)
    } catch SuuntoNauticExplorer.ExplorerError.requestFailed(let status) {
      return .stop(stopped ?? status)
    } catch {
      return .stop(stopped ?? DC_STATUS_IO)
    }
    if let stopped { return .stop(stopped) }
    return busy ? .waited : .free
  }

  /// Yields the busy event, waits for the watch to push free and yields it; nil once free, or
  /// the status that ended the wait.
  private func waitForFree(
    _ handle: OpaquePointer, _ subscription: SuuntoNauticExplorer.Subscription
  ) -> dc_status_t? {
    events.yield(.busy(true))
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
    events.yield(.busy(false))
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
