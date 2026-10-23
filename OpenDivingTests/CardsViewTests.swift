import OpenDivingKit
import SwiftUI
import Testing
import UIKit

@testable import OpenDiving

/// The Cards view under an injected session, signed in and — from the cache — signed out.
@MainActor
struct CardsViewTests {
  private static let origin = ServerOrigin("https://stub.opendiving.invalid")!

  private static let routes: [String: StubTransport.Response] = [
    "GET user": .json(
      """
      {"uuid":"01a0a51f-afe3-7363-a0bc-b0d634c35923","name":"Test Diver","username":"testdiver",
       "email":"diver@example.com","portrait_sha256":null,"units":"metric"}
      """),
    "GET people": .json(
      #"{"data":[],"total_count":0,"has_more":false,"page":1,"items_per_page":50}"#),
    "GET user/checkin-details": .json(
      """
      {"email":null,"phone":"+20 100 000 0000","date_of_birth":"1988-04-12",
       "emergency_contacts":[],"insurance_policies":[]}
      """),
    "GET user/dive-stats": .json(
      """
      {"total_dives":3,"max_depth":18.5,"total_submerged_time":7200,"species_seen":0,
       "dive_site_count":1,"first_dive_on":null,"last_dive_on":null,
       "user_uuid":"01a0a51f-afe3-7363-a0bc-b0d634c35923","created_at":"2026-09-15T12:53:28Z"}
      """),
    "GET dives": .json(
      #"{"data":[],"total_count":0,"has_more":false,"page":1,"items_per_page":1}"#),
    "GET certifications": .json(
      """
      {"data":[{"uuid":"01a0b07a-206e-76bd-bc56-e9646791ba20","agency":"padi","agency_other":null,
        "name":"Open Water Diver","certification_number":"123","certified_on":"2020-01-02",
        "expires_on":null,"instructor_number":null,"notes":"",
        "user_uuid":"01a0a51f-afe3-7363-a0bc-b0d634c35923","course_uuid":null,
        "contact_uuid":null,"instructor_uuid":null,"files":[],
        "created_at":"2026-09-17T17:46:28Z"}],
       "total_count":1,"has_more":false,"page":1,"items_per_page":50}
      """),
    "POST auth/logout": .json(#"{"message":"Logged out successfully"}"#),
  ]

  private func host(_ session: Session) -> UIView? {
    let host = UIHostingController(rootView: CardsView().environment(session))
    host.loadViewIfNeeded()
    host.view.layoutIfNeeded()
    return host.viewIfLoaded
  }

  @Test func hostsSignedIn() {
    let session = Session.stub(origin: Self.origin, transport: StubTransport(routes: Self.routes))
    #expect(host(session) != nil)
  }

  @Test func signedOutItReadsTheCachedSheet() async throws {
    let session = Session.stub(origin: Self.origin, transport: StubTransport(routes: Self.routes))
    let model = CheckinSheetModel(session: session)
    await model.refresh()
    #expect(model.refreshError == nil)
    try await session.signOut()

    #expect(host(session) != nil)
    let signedOut = CheckinSheetModel(session: session)
    signedOut.load()
    #expect(signedOut.content?.name == "Test Diver")
    #expect(signedOut.content?.cards.map(\.name) == ["Open Water Diver"])
  }
}
