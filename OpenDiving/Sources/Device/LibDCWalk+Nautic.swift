@preconcurrency import Clibdivecomputer
import Foundation
@preconcurrency import LibDCSwift
import OpenDivingKit

/// A Suunto Nautic-family watch, walked by id: the identity, the zone, a wait while the watch says
/// it is busy, the logbook listed, each entry's sport learned from its summary — or from the
/// record, where an earlier walk kept it — and counted, then each new entry downloaded by id
/// unless its summary names a sport that is no dive. Which entries are summarised, counted and
/// downloaded is ``NauticSelection``'s.
nonisolated extension LibDCWalk {
  func walkNautic(_ handle: OpaquePointer, serial: String) -> DiveComputerDownloadEnd {
    let (_, info) = Self.buffered { suunto_nautic_device_fetch(handle, NauticInfo.path, $0) }
    identify(
      serial: serial,
      firmware: NauticInfo.firmware(info).flatMap { LibDCNames.firmware($0, family: family) })
    let record = lookup(family, serial)
    let fingerprint = record?.fingerprintToSet
    readWatchZone()

    if let status = waitWhileBusy(handle) { return nauticEnd(status) }

    let (listed, list) = Self.buffered { suunto_nautic_device_list(handle, $0) }
    guard listed == DC_STATUS_SUCCESS else { return nauticEnd(listed) }
    let ids = Self.nauticIDs(list)

    var learned: [UInt32: NauticSelection.Summary] = [:]
    var descriptors: NauticDescriptors?
    var descriptorsRead = false
    for id in NauticSelection.summariesNeeded(ids: ids, remembered: record?.nauticSports) {
      if cancel.isSet { return nauticEnd(DC_STATUS_CANCELLED) }
      let (status, summary) = Self.buffered {
        suunto_nautic_device_download_summary(handle, String(id), $0)
      }
      switch Self.nauticSummary(status: status, bytes: summary) {
      case .stop(let stopped): return nauticEnd(stopped)
      case .empty: learned[id] = .empty
      case .unread: learned[id] = .unread
      case .bytes:
        // One entry's descriptors serve the walk: a summary another firmware laid out does not
        // fit them and decodes to no sport.
        if !descriptorsRead {
          descriptorsRead = true
          let (status, bytes) = Self.buffered {
            suunto_nautic_device_fetch_paged(handle, NauticDescriptors.path(id), $0)
          }
          switch Self.nauticSummary(status: status, bytes: bytes) {
          case .stop(let stopped): return nauticEnd(stopped)
          case .bytes: descriptors = NauticDescriptors(bytes)
          case .empty, .unread: break
          }
        }
        learned[id] = descriptors.map { .read(sport: $0.sport(inSummary: summary)) } ?? .unread
      }
    }

    let selection = NauticSelection(
      ids: ids, fingerprint: fingerprint, remembered: record?.nauticSports, learned: learned)
    events.yield(.listing(selection.listing))

    for entry in selection.entries {
      if cancel.isSet { break }
      let mark = NauticSelection.fingerprint(entry.id)
      if entry.fate == .skip {
        events.yield(.skipped(fingerprint: mark))
        continue
      }
      let (status, bytes) = Self.buffered {
        suunto_nautic_device_download(handle, String(entry.id), $0)
      }
      switch Self.nauticDownload(status: status, bytes: bytes) {
      case .stop(let stopped): return nauticEnd(stopped)
      case .passOver: break
      case .deliver(let dive):
        guard self.dive(dive, fingerprint: mark) else { return nauticEnd(DC_STATUS_CANCELLED) }
      }
    }
    return nauticEnd(DC_STATUS_SUCCESS)
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

  /// What a by-id download's answer means for the walk. The backend checks a download against
  /// its listed size and leaves the content to the parser, so a session that holds no dive comes
  /// back as bytes, and ``LibDCWalk/dive(_:fingerprint:)`` skips it. A failure carries no bytes
  /// and is not retried by the backend: a stalled stream answers `DC_STATUS_TIMEOUT`, a dive
  /// short of its listed size or one whose summary cannot be fetched fails too, and a link
  /// dropped mid-transfer answers `DC_STATUS_NODEVICE`, nothing resuming it.
  enum NauticDownload: Equatable {
    /// A profile, the summary appended: handed on to be parsed.
    case deliver(Data)
    /// Success with no bytes, which an entry listed with size 0 gives. Passed over, yielding
    /// nothing, so the fingerprint is moved only by an entry delivered or skipped.
    case passOver
    /// Any failure: the walk ends on it.
    case stop(dc_status_t)
  }

  static func nauticDownload(status: dc_status_t, bytes: Data) -> NauticDownload {
    guard status == DC_STATUS_SUCCESS else { return .stop(status) }
    return bytes.isEmpty ? .passOver : .deliver(bytes)
  }

  /// What a summary's or the descriptors' fetch answered.
  enum NauticAnswer: Equatable {
    case bytes
    case empty
    /// Refused or broken off: the entry counts and downloads as a dive, and is summarised again
    /// on the next walk.
    case unread
    /// Cancelled, or the link is gone, which every later fetch would meet too.
    case stop(dc_status_t)
  }

  static func nauticSummary(status: dc_status_t, bytes: Data) -> NauticAnswer {
    switch status {
    case DC_STATUS_SUCCESS: bytes.isEmpty ? .empty : .bytes
    case DC_STATUS_CANCELLED, DC_STATUS_IO, DC_STATUS_NODEVICE: .stop(status)
    default: .unread
    }
  }

  /// Waits while the watch says it is busy with another app, in waits of a second so a cancel
  /// ends it at the next; nil once it is free, or the status that ended the walk. A watch with no
  /// such resource, or that refuses it, is not waited for. Unsubscribed before anything is
  /// listed, since a subscription is not valid while a download runs.
  private func waitWhileBusy(_ handle: OpaquePointer) -> dc_status_t? {
    guard
      let subscription = try? SuuntoNauticExplorer.subscribe(
        dcDevice: handle, path: Self.busyStatePath)
    else { return nil }
    defer { try? SuuntoNauticExplorer.unsubscribe(dcDevice: handle, subscription) }
    guard Self.isBusy(subscription.initialValue) else { return nil }
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
      emptyReads: emptyReads, refused: refused, fingerprintSet: false)
  }
}
