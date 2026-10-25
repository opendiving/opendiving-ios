import OpenDivingKit
import Testing

@testable import OpenDiving

/// The connectivity seam over a path the test hands it.
struct PathMonitorConnectivityTests {
  private let wifi = PathMonitorConnectivity.Path(satisfied: true, interfaces: ["wifi"])
  private let cellular = PathMonitorConnectivity.Path(satisfied: true, interfaces: ["cellular"])
  private let none = PathMonitorConnectivity.Path(satisfied: false, interfaces: [])

  /// The moments `connectivity` reports while `body` runs, collected until `count` arrive.
  private func moments(
    _ connectivity: PathMonitorConnectivity, count: Int, _ body: () -> Void
  ) async -> [ConnectivityMoment] {
    let stream = connectivity.moments()
    body()
    var seen: [ConnectivityMoment] = []
    for await moment in stream {
      seen.append(moment)
      if seen.count == count { break }
    }
    return seen
  }

  @Test func aRouteIsReportedWhenThePathIsSatisfied() {
    let connectivity = PathMonitorConnectivity(monitor: nil)
    #expect(connectivity.isRouteAvailable)
    connectivity.receive(none)
    #expect(!connectivity.isRouteAvailable)
    connectivity.receive(wifi)
    #expect(connectivity.isRouteAvailable)
  }

  @Test func everyRouteAppearingIsCounted() {
    let connectivity = PathMonitorConnectivity(monitor: nil)
    connectivity.receive(none)
    #expect(connectivity.routeAppearances == 0)
    connectivity.receive(wifi)
    connectivity.receive(wifi)
    connectivity.receive(none)
    connectivity.receive(cellular)
    #expect(connectivity.routeAppearances == 2)
  }

  @Test func aSatisfiedPathThatChangedIsAMomentAndOneThatDidNotIsNone() async {
    let connectivity = PathMonitorConnectivity(monitor: nil)
    let seen = await moments(connectivity, count: 4) {
      connectivity.receive(wifi)
      connectivity.receive(wifi)
      connectivity.receive(none)
      connectivity.receive(wifi)
      connectivity.receive(cellular)
      connectivity.becameActive()
    }
    #expect(seen == [.routeAppeared, .routeAppeared, .routeAppeared, .becameActive])
  }

  @Test func eachSubscriptionHearsEveryMoment() async {
    let connectivity = PathMonitorConnectivity(monitor: nil)
    let first = connectivity.moments()
    let seen = await moments(connectivity, count: 1) { connectivity.becameActive() }
    var other: [ConnectivityMoment] = []
    for await moment in first {
      other.append(moment)
      break
    }
    #expect(seen == [.becameActive])
    #expect(other == [.becameActive])
  }
}
