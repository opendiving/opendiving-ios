import OpenDivingKit
import SwiftUI
import Testing
import UIKit

@testable import OpenDiving

/// The credit sheet a species card opens reads the species it credits.
@MainActor
struct SpeciesPhotoCreditSheetTests {
  @Test func theSheetAsksForTheSpecies() async throws {
    let uuid = SpeciesPhotoCreditSheet.previewUUID
    let route = "GET species/\(uuid.uuidString.lowercased())"
    let transport = StubTransport(routes: [:])
    let scene = try #require(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.rootViewController = UIHostingController(
      rootView: SpeciesPhotoCreditSheet(
        speciesUUID: uuid, photoVersion: "ab12",
        content: SpeciesCardContent(commonName: "Twoband anemonefish", scientificName: "x")
      )
      .environment(Session.stub(transport: transport)))
    window.makeKeyAndVisible()
    defer { window.isHidden = true }

    var asked = false
    for _ in 0..<200 where !asked {
      asked = transport.requests.map(StubTransport.routeKey).contains(route)
      if !asked { try? await Task.sleep(for: .milliseconds(10)) }
    }
    #expect(asked)
  }
}
