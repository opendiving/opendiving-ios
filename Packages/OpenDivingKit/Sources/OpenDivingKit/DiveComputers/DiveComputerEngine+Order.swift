import Foundation

/// The account's order of its dive computers, read and set on the server, and the question a
/// computer paired beside exactly one other waits for (``DiveComputerRecord/awaitsOrder``).
extension DiveComputerEngine {
  /// `GET /dive-computers` into ``order``, with a route and the account loaded. A failure keeps
  /// the order last read.
  public func readOrder() async {
    guard let client = orderClient() else { return }
    do {
      order = try await client.diveComputers()
      orderRouteMissing = false
    } catch APIError.http(404, _) {
      order = nil
      orderRouteMissing = true
    } catch {}
  }

  /// `PUT /dive-computers/order` with `serials`, first to last, its answer becoming ``order``.
  /// Whether the server took it, or has no such route to take it with.
  @discardableResult
  public func setOrder(_ serials: [String]) async -> Bool {
    guard let client = orderClient() else { return false }
    do {
      order = try await client.setDiveComputerOrder(serials)
      return true
    } catch APIError.http(404, _) {
      order = nil
      orderRouteMissing = true
      return true
    } catch {
      return false
    }
  }

  /// The answer to *Which computer comes first?* for `record`: `serials` sent as the order, or
  /// with nil nothing to send, the question no longer standing. Once taken, the computer's dives
  /// go up. False where the answer could not be sent, the question standing.
  @discardableResult
  public func answerOrder(_ serials: [String]?, for record: DiveComputerRecord) async -> Bool {
    if let serials, !(await setOrder(serials)) { return false }
    guard let origin = session.state.origin, let (account, _) = keeping() else { return false }
    let store = DiveComputerStore(store: session.store, origin: origin, account: account)
    if var answered = store.record(family: record.family, serial: record.serial),
      answered.awaitsOrder
    {
      answered.awaitsOrder = false
      try? store.save(answered)
    }
    reload()
    upload()
    return true
  }

  /// The records of `account` whose dives wait for the order's question.
  func awaitingOrder(origin: ServerOrigin, account: UUID) -> Set<String> {
    Set(
      DiveComputerStore(store: session.store, origin: origin, account: account).records()
        .filter(\.awaitsOrder).map(\.id))
  }

  private func orderClient() -> APIClient? {
    guard case .signedIn = session.state, session.accountLoaded,
      session.connectivity.isRouteAvailable
    else { return nil }
    return try? session.requireClient()
  }
}
