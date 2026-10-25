import OpenDivingKit
import SwiftUI
import Testing
import UIKit

@testable import OpenDiving

/// Each record sheet hosts and draws the web dialog's fields. SwiftUI builds no accessibility
/// tree without an assistive technology running, so the fields are found by what UIKit draws
/// for them: the title, each box's placeholder — the web's — or its label where it has none,
/// and each pick-list's current choice.
@MainActor
struct RecordSheetsTests {
  /// Every text UIKit draws for the sheet, the window tall enough that the form draws every
  /// row rather than only those a phone's screen shows.
  private func texts(_ view: some View) async throws -> Set<String> {
    let scene = try #require(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(x: 0, y: 0, width: 430, height: 6000)
    let session = Session.stub(transport: StubTransport(routes: [:]))
    window.rootViewController = UIHostingController(rootView: view.environment(session))
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    var found: Set<String> = []
    for _ in 0..<50 {
      try? await Task.sleep(for: .milliseconds(20))
      window.layoutIfNeeded()
      found = Self.collect(window)
      if !found.isEmpty { break }
    }
    return found
  }

  private static func collect(_ root: NSObject) -> Set<String> {
    var found: Set<String> = []
    var queue: [NSObject] = [root]
    var seen: Set<ObjectIdentifier> = []
    while let next = queue.popLast() {
      guard seen.insert(ObjectIdentifier(next)).inserted else { continue }
      for text in [next.accessibilityLabel, next.accessibilityValue] {
        if let text, !text.isEmpty { found.insert(text) }
      }
      if let label = next as? UILabel, let text = label.text { found.insert(text) }
      if let field = next as? UITextField {
        for text in [field.placeholder, field.text] {
          if let text, !text.isEmpty { found.insert(text) }
        }
      }
      if let button = next as? UIButton, let title = button.currentTitle { found.insert(title) }
      if let view = next as? UIView { queue += view.subviews }
      if let elements = next.accessibilityElements as? [NSObject] { queue += elements }
      let count = next.accessibilityElementCount()
      if count != NSNotFound, count > 0 {
        for index in 0..<count {
          if let element = next.accessibilityElement(at: index) as? NSObject {
            queue.append(element)
          }
        }
      }
    }
    return found
  }

  private func expectFields(_ texts: [String], in found: Set<String>) {
    for text in texts {
      #expect(found.contains(text), "\(text) not drawn")
    }
  }

  @Test func theDiveSiteSheetDrawsTheWebsFields() async throws {
    let found = try await texts(NewDiveSiteSheet { _ in })
    expectFields(
      [
        "New Dive Site", "e.g. Blue Hole", "e.g. Dahab, South Sinai, Egypt", "e.g. 27.8506",
        "e.g. 34.3136", "e.g. 5", "e.g. 30", "e.g. 372", "Not recorded", "Add a tag...",
        "Any notes about this dive site...",
      ], in: found)
  }

  @Test func thePersonSheetDrawsTheWebsFields() async throws {
    let found = try await texts(NewPersonSheet { _ in })
    expectFields(
      [
        "New Person", "e.g. Alex M.", "e.g. alexm", "Email", "Phone",
        "How you met, what they dive, anything worth remembering...",
      ], in: found)
  }

  @Test func theTripSheetDrawsTheWebsFields() async throws {
    let found = try await texts(NewTripSheet { _ in })
    expectFields(
      ["New Trip", "e.g. Red Sea Liveaboard 2024", "Any notes about this trip..."], in: found)
  }

  @Test func theCourseSheetDrawsTheWebsFields() async throws {
    let found = try await texts(NewCourseSheet { _ in })
    expectFields(
      [
        "New Course", "e.g. Advanced Nitrox + Decompression Procedures", "No agency",
        "Completed", "Instructor number",
        "Skills covered, conditions, anything worth remembering...",
      ], in: found)
  }

  @Test func theContactSheetDrawsTheWebsFields() async throws {
    let found = try await texts(NewContactSheet { _ in })
    expectFields(
      [
        "New Contact", "e.g. Blue Ocean Dive Center", "Phone", "Email", "e.g. blueocean.com",
        "Street, number, building, unit", "City", "Postcode", "Region", "Country",
        "e.g. 27.8506", "e.g. 34.3136", "Opening hours, who to ask for, what to bring...",
      ], in: found)
  }

  @Test func theGearSheetShowsACylindersFactsOnlyForACylinder() async throws {
    let plain = try await texts(NewGearItemSheet { _ in })
    expectFields(
      [
        "New Gear", "e.g. MK25 EVO", "e.g. Scubapro", "No type",
        "Serial number, service dates, sizing...",
      ], in: plain)
    #expect(!plain.contains("e.g. 232"))

    let cylinder = try await texts(NewGearItemSheet(type: "cylinder") { _ in })
    expectFields(["Cylinder", "e.g. 11.1", "e.g. 232", "Not recorded"], in: cylinder)
  }

  @Test func aTanksCylinderPickerAddsACylinder() async throws {
    let cylinder = try await texts(FormPicker.cylinder.addSheet { _ in })
    expectFields(["New Gear", "Cylinder", "e.g. 11.1", "e.g. 232"], in: cylinder)
    let gear = try await texts(FormPicker.gear.addSheet { _ in })
    expectFields(["New Gear", "No type"], in: gear)
  }

  @Test func saveAsSetOpensOnTheDivesWeightAndANewSet() async throws {
    let found = try await texts(SaveGearSetSheet(items: [], weight: 6) { _ in })
    expectFields(
      ["Save as Set", "Create a new set", "e.g. Sidemount, Warm water rec", "6"], in: found)
  }
}
