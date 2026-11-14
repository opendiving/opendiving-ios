import Foundation
import Synchronization

/// Keeps one walk's dives on disk as they arrive, called by the link on its own queue before the
/// walk's next transfer starts, so an app ended mid-walk loses at most the dive in transfer.
final class WalkKeeper: Sendable {
  let id: UUID
  private let store: DownloadStore
  private let walk: Mutex<KeptWalk>

  init(store: DownloadStore, marked: Bool, startedAt: Date) {
    let walk = KeptWalk(
      id: UUID(), receivedBeforeAccountKnown: marked, startedAt: startedAt, heldForZone: false,
      announced: false, dives: [])
    id = walk.id
    self.store = store
    self.walk = Mutex(walk)
  }

  /// Writes the dive's files, then the record naming them. A dive that cannot be written is not
  /// kept, as an archive that cannot be written is not.
  func keep(_ dive: DownloadedDive) {
    walk.withLock { walk in
      let kept = KeptDive(dive, file: "\(walk.dives.count).bin")
      let folder = store.folder(of: walk.id)
      do {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try kept.write(dive, into: folder)
        var next = walk
        next.dives.append(kept)
        try store.save(next)
        walk = next
      } catch {}
    }
  }

  /// The computer the walk identified, and the zone its watch reported.
  func identified(record: String?, zone: TimeZone?) {
    walk.withLock { walk in
      var next = walk
      if let record { next.record = record }
      if let zone { next.zone = zone }
      guard next != walk else { return }
      walk = next
      if !walk.dives.isEmpty { try? store.save(walk) }
    }
  }

  var kept: KeptWalk { walk.withLock { $0 } }
}
