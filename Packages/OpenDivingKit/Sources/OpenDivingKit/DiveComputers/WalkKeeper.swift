import Foundation
import Synchronization

/// Keeps one walk's dives on disk as they arrive, called by the link on its own queue before the
/// walk's next transfer starts, so an app ended mid-walk loses at most the dive in transfer.
final class WalkKeeper: Sendable {
  let id: UUID
  private let store: DownloadStore
  private let state: Mutex<State>

  private struct State {
    var walk: KeptWalk
    /// Files named so far: a dive cut into an archive leaves the walk, so its count would name
    /// a later dive's file after one still kept.
    var files = 0
  }

  init(store: DownloadStore, marked: Bool, startedAt: Date) {
    let walk = KeptWalk(
      id: UUID(), receivedBeforeAccountKnown: marked, startedAt: startedAt, heldForZone: false,
      announced: false, dives: [])
    id = walk.id
    self.store = store
    state = Mutex(State(walk: walk))
  }

  /// Writes the dive's files, then the record naming them. A dive that cannot be written is not
  /// kept, as an archive that cannot be written is not.
  func keep(_ dive: DownloadedDive) {
    state.withLock { state in
      let kept = KeptDive(dive, file: "\(state.files).bin")
      state.files += 1
      let folder = store.folder(of: state.walk.id)
      do {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try kept.write(dive, into: folder)
        var next = state.walk
        next.dives.append(kept)
        try store.save(next)
        state.walk = next
      } catch {}
    }
  }

  /// The computer the walk identified, and the zone its watch reported.
  func identified(record: String?, zone: TimeZone?) {
    state.withLock { state in
      var next = state.walk
      if let record { next.record = record }
      if let zone { next.zone = zone }
      guard next != state.walk else { return }
      state.walk = next
      if !next.dives.isEmpty { try? store.save(next) }
    }
  }

  /// The dives the walk takes because the logbook holds them without the computer's original,
  /// each with the dive that holds it: an ended process's archive of them still says so.
  func updating(_ dives: [UUID: UUID]) {
    state.withLock { state in
      var next = state.walk
      next.updating = dives.isEmpty ? nil : dives
      guard next != state.walk else { return }
      state.walk = next
      if !next.dives.isEmpty { try? store.save(next) }
    }
  }

  /// The dives an archive now holds leave the walk: the record first, then their files. A
  /// record left naming them is read past by the next launch, which leaves out what an archive
  /// holds.
  func archived(_ fingerprints: Set<Data>) {
    state.withLock { state in
      let leaving = state.walk.dives.filter {
        Hex.data($0.fingerprint).map(fingerprints.contains) ?? false
      }
      guard !leaving.isEmpty else { return }
      state.walk.dives.removeAll { leaving.contains($0) }
      guard (try? store.save(state.walk)) != nil else { return }
      let folder = store.folder(of: state.walk.id)
      for dive in leaving { dive.remove(from: folder) }
    }
  }

  var kept: KeptWalk { state.withLock { $0.walk } }
}
