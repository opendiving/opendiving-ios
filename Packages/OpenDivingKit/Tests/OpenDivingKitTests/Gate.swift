/// Holds one request until the test opens it, and says when that request has arrived.
actor Gate {
  private var held: CheckedContinuation<Void, Never>?
  private var arrival: CheckedContinuation<Void, Never>?
  private var arrived = false

  func pass() async {
    arrived = true
    arrival?.resume()
    arrival = nil
    await withCheckedContinuation { held = $0 }
  }

  func untilArrived() async {
    guard !arrived else { return }
    await withCheckedContinuation { arrival = $0 }
  }

  func open() {
    held?.resume()
    held = nil
  }
}
