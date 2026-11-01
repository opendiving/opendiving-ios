import Foundation
import Observation

/// A page head's map: the tiles of a ``MapBackdropLayout`` once every one of them is to hand,
/// and the credit they owe.
///
/// Tiles the phone holds show at once, before the instance has said whether it draws any;
/// the rest are asked for only where it does and names their credit. A set shows whole or not
/// at all, and the last whole set stays until the next one is. A tile that cannot be had
/// leaves the band without a map, and is asked for again only when the head next appears:
/// a renderer that failed is down or busy, and asking on a timer would add to it.
@MainActor
@Observable
public final class MapBackdropModel {
  public struct Shown: Hashable, Sendable {
    public let layout: MapBackdropLayout
    public let images: [MapTileAddress: Data]
    /// A markdown link, as the instance names it.
    public let credit: String
  }

  public private(set) var shown: Shown?

  @ObservationIgnored private let session: Session
  /// Bumped by every ``show(_:)``, so one superseded by another while it waited lands nothing.
  @ObservationIgnored private var generation = 0

  public init(session: Session) {
    self.session = session
  }

  public func show(_ layout: MapBackdropLayout?) async {
    generation += 1
    let current = generation
    guard let layout, let store = session.mapTileStore() else {
      shown = nil
      return
    }
    let addresses = Set(layout.tiles.map(\.address))
    var images: [MapTileAddress: Data] = [:]
    for address in addresses {
      images[address] = await store.stored(address)
    }
    let heldCredit = await store.credit()
    guard current == generation else { return }
    if images.count == addresses.count, let heldCredit {
      shown = Shown(layout: layout, images: images, credit: heldCredit)
    }

    // No answer is no reason to take down what the phone holds.
    guard let config = await session.mapConfig() else { return }
    guard current == generation else { return }
    guard config.mapTiles == true, let credit = config.mapAttribution else {
      shown = nil
      return
    }
    await store.remember(credit: credit)

    // What is missing, and what is held but not asked about since launch.
    let asking = addresses.filter { images[$0] == nil }
      .union(await store.notAsked(among: addresses))
    let fetched = await withTaskGroup(of: (MapTileAddress, Data?).self) { group in
      for address in asking {
        group.addTask { (address, await store.fetch(address)) }
      }
      var fetched: [MapTileAddress: Data] = [:]
      for await (address, data) in group {
        fetched[address] = data
      }
      return fetched
    }
    guard current == generation, !Task.isCancelled else { return }
    images.merge(fetched) { $1 }
    shown =
      images.count == addresses.count
      ? Shown(layout: layout, images: images, credit: credit) : nil
  }
}
