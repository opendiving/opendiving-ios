import Foundation
import OpenDivingKit
import SwiftUI
import Testing
import UIKit

@testable import OpenDiving

@MainActor
struct DiveProfileChartViewTests {
  /// The card's recording switcher changes `recordingUUID` on the chart it already shows;
  /// the chart has to ask for the new recording without the card resetting its identity.
  @Test func switchingTheRecordingRequestsItsProfile() async throws {
    let dive = UUID()
    let first = UUID()
    let second = UUID()
    let profile = ProfileChartPlot.previewJSON
    let transport = StubTransport { _ in .json(profile) }
    let selection = Selection(recording: first)
    let host = UIHostingController(
      rootView: SwitchingChart(dive: dive, selection: selection)
        .environment(Session.stub(transport: transport)))

    let scene = try #require(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.rootViewController = host
    window.makeKeyAndVisible()
    defer { window.isHidden = true }

    let route = { (recording: UUID) in
      "GET dive/\(dive.uuidString.lowercased())/recording/\(recording.uuidString.lowercased())/profile"
    }
    try await waitUntil { transport.requests.map(StubTransport.routeKey).contains(route(first)) }

    selection.recording = second
    try await waitUntil { transport.requests.map(StubTransport.routeKey).contains(route(second)) }
    #expect(transport.requests.map(StubTransport.routeKey).last == route(second))
  }

  private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0..<100 {
      if condition() { return }
      try await Task.sleep(for: .milliseconds(50))
    }
    Issue.record("Timed out")
  }
}

@MainActor
@Observable
private final class Selection {
  var recording: UUID

  init(recording: UUID) {
    self.recording = recording
  }
}

private struct SwitchingChart: View {
  let dive: UUID
  let selection: Selection

  var body: some View {
    DiveProfileChartView(diveUUID: dive, recordingUUID: selection.recording, cylinderLabels: [1])
  }
}
