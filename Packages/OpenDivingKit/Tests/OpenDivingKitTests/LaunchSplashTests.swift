import Foundation
import OpenDivingKit
import Synchronization
import Testing

@MainActor
struct LaunchSplashTests {
  /// Stands in for the clock: records every sleep, and holds the ones it is told to until
  /// they are cancelled.
  private final class Sleeper: Sendable {
    private let held: Set<Duration>
    private let slept = Mutex<[Duration]>([])

    init(holding held: Set<Duration> = []) {
      self.held = held
    }

    var durations: [Duration] { slept.withLock { $0 } }

    func sleep(_ duration: Duration) async throws {
      slept.withLock { $0.append(duration) }
      if held.contains(duration) { try await Task.sleep(for: .seconds(3600)) }
    }
  }

  private func splash(_ sleeper: Sleeper) -> LaunchSplash {
    LaunchSplash(
      minimum: .seconds(1), settle: .milliseconds(150), ceiling: .seconds(5),
      sleep: { try await sleeper.sleep($0) })
  }

  /// A session with a request on the wire that stays there until the transport is released.
  private func busySession() async -> (Session, SilentTransport, Task<Void, Never>) {
    let transport = SilentTransport()
    let session = Session.stub(transport: transport)
    let asking = Task { _ = try? await session.validate(session.state.origin!) }
    while session.requests.inFlight == 0 { await Task.yield() }
    return (session, transport, asking)
  }

  @Test func anIdleSessionHasTheSplashDownAfterTheMinimum() async {
    let sleeper = Sleeper(holding: [.seconds(4)])
    let splash = splash(sleeper)
    await splash.run(Session.stub(transport: StubTransport(routes: [:])).requests)
    #expect(!splash.isShowing)
    #expect(sleeper.durations.first == .seconds(1))
  }

  @Test func theSplashStaysUpWhileARequestIsOnTheWire() async {
    let (session, transport, asking) = await busySession()
    let sleeper = Sleeper(holding: [.seconds(4)])
    let splash = splash(sleeper)
    let running = Task { await splash.run(session.requests) }
    for _ in 0..<50 { await Task.yield() }
    #expect(splash.isShowing)

    transport.release()
    await asking.value
    await running.value
    #expect(!splash.isShowing)
    #expect(session.requests.inFlight == 0)
    #expect(sleeper.durations.contains(.milliseconds(150)))
  }

  @Test func theCeilingTakesTheSplashDownOverARequestThatNeverAnswers() async {
    let (session, transport, asking) = await busySession()
    let splash = splash(Sleeper())
    await splash.run(session.requests)
    #expect(!splash.isShowing)
    #expect(session.requests.inFlight > 0)
    transport.release()
    await asking.value
  }

  @Test func anUploadIsNotCounted() async throws {
    let transport = SilentTransport()
    let session = Session.stub(transport: transport)
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent("LaunchSplashTests-\(UUID().uuidString)")
    try Data("dive".utf8).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }
    let uploading = Task {
      _ = try? await session.client!.importPreview(files: [
        ImportFile(file: file, filename: "dive.fit")
      ])
    }
    while transport.requests.isEmpty { await Task.yield() }
    #expect(session.requests.inFlight == 0)
    transport.release()
    await uploading.value
  }
}
