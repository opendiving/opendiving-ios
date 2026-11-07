import Foundation

/// How a site's queued writes came out for a form waiting on them.
public enum DiveSiteLanding: Hashable, Sendable {
  /// Nothing of it is left to send, and this is what the server holds.
  case landed(DiveSiteRead)
  /// It stays on the phone for now, under this ref: no route, a refusal Pending holds, or an
  /// answer the outbox retries later. Also a read that failed once nothing was left to send.
  case kept(RecordRef)
}

extension OutboxModel {
  /// Waits out the writes of `ref`, for as long as a flush is getting anywhere with them, and
  /// reads the site. A pass that ends with one still queued has said all it will for now.
  public func landing(ofSite ref: RecordRef) async -> DiveSiteLanding {
    guard let stores = AccountStores.current(session) else { return .kept(ref) }
    let hub = OutboxHub.hub(for: stores.directory)
    var ref = Self.resolved(ref, in: stores.outbox)
    // An earlier write of the site may be waiting for nothing but a pass.
    if hub.flush == nil, stores.outbox.items().contains(where: { $0.record == ref }) {
      requestFlush(retryAll: false)
    }
    while true {
      ref = Self.resolved(ref, in: stores.outbox)
      let writes = stores.outbox.items().filter { $0.record == ref }
      if writes.isEmpty { break }
      guard session.connectivity.isRouteAvailable, !writes.contains(where: \.isFailed),
        let flush = hub.flush
      else { return .kept(ref) }
      await flush.value
    }
    guard let uuid = ref.serverUUID,
      let site = try? await session.requireClient().diveSite(uuid)
    else { return .kept(ref) }
    return .landed(site)
  }

  /// The server's ref for a create that has landed.
  private static func resolved(_ ref: RecordRef, in outbox: OutboxStore) -> RecordRef {
    guard case .local(let local) = ref, let server = outbox.resolutions()[local]?.server else {
      return ref
    }
    return .server(server)
  }
}
