import Foundation
import Testing

@testable import OpenDiving

struct NetworkConfigurationTests {
  @Test func waitsForConnectivityForAMinuteAtMost() {
    let configuration = NetworkConfiguration.make()
    #expect(configuration.waitsForConnectivity)
    #expect(configuration.timeoutIntervalForResource <= 60)
  }
}
