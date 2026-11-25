import Foundation
import Testing

@testable import OpenDivingKit

/// What the list's cards, a certification's pane and the form's slots are given, in the web's
/// words, and the framing's geometry.
struct CertificationContentTests {
  private static let today = CalendarDate(year: 2026, month: 11, day: 10)!

  private static func stored() throws -> CertificationRead {
    try KitFixture.decode(CertificationRead.self, "certification-front-only")
  }

  // MARK: - The list's card

  @Test func aCardCarriesItsLevelAgencyAndFront() throws {
    let card = CertificationCardContent(try Self.stored(), today: Self.today)
    #expect(card.name == "Solo Diver" && card.agency == "SDI")
    #expect(card.front?.side == "front" && card.badge == nil)
    #expect(card.missingFrontIcon == .tabImageOff)
  }

  @Test func aCardWithNoFrontOrAPDFDrawsItsIcon() throws {
    let bare = try Self.decode(files: "[]", expires: "2026-12-01")
    let card = CertificationCardContent(bare, today: Self.today)
    #expect(card.front == nil && card.missingFrontIcon == .tabBadgeCheck)
    #expect(card.badge == Badge("Expiring soon", style: .coral))
    #expect(card.agency == "PADI")

    let pdf = try Self.decode(
      files: #"[{"uuid":"01a0b07a-2e5b-792f-b35b-98009ab92953","side":"front","#
        + #""content_type":"application/pdf","byte_size":10,"original_filename":"c.pdf"}]"#)
    let pdfCard = CertificationCardContent(pdf, today: Self.today)
    #expect(pdfCard.front == nil && pdfCard.missingFrontIcon == .tabFileText)
  }

  // MARK: - The pane

  @Test func thePaneListsItsRowsInOrderLinkingTheCourseAndInstructor() throws {
    let certification = try Self.stored()
    let page = CertificationPageContent(
      certification, today: Self.today, courseName: "Solo course", contactName: "Blue Ocean",
      instructor: PersonRowContent(uuid: certification.instructorUuid, name: "Kim"))
    #expect(
      page.rows.map(\.label) == [
        "Certification", "Agency", "Certification number", "Course", "Certified on",
        "Dive center", "Instructor", "Instructor number",
      ])
    #expect(CertificationPageContent.title(certification) == "SDI Solo Diver")
    #expect(page.rows[0].value == "Solo Diver" && page.rows[1].value == "SDI")
    #expect(page.rows[3].link == .course(certification.courseUuid!))
    #expect(page.rows[6].link == .person(certification.instructorUuid!))
    #expect(page.rows.allSatisfy { $0.badge == nil })
    #expect(page.notes == nil)
  }

  @Test func onlyTheSidesWithAFileAreDrawn() throws {
    let frontOnly = CertificationPageContent(
      try Self.stored(), today: Self.today, courseName: nil, contactName: nil, instructor: nil)
    #expect(frontOnly.sides.map(\.title) == ["Front"])

    let bare = CertificationPageContent(
      try Self.decode(files: "[]"), today: Self.today, courseName: nil, contactName: nil,
      instructor: nil)
    #expect(bare.sides.isEmpty)
  }

  @Test func theExpiryDateCarriesTheBadge() throws {
    let page = CertificationPageContent(
      try Self.decode(files: "[]", expires: "2026-12-01"), today: Self.today, courseName: nil,
      contactName: nil, instructor: nil)
    let expires = try #require(page.rows.first { $0.label == "Expires on" })
    #expect(expires.badge == .expiringSoon)
  }

  @Test func aConnectedInstructorCarriesTheirUsernameAndPicture() throws {
    let page = try KitFixture.decode(PaginatedListResponse<PersonRead>.self, "people-page")
    let people = Dictionary(uniqueKeysWithValues: page.data.map { ($0.uuid, $0) })
    let ana = try #require(UUID(uuidString: "01a0e2ed-1be1-7142-996d-0639721e344d"))
    let picture = ConnectedPicture(
      source: .person(ana),
      version: "b5bb9d8014a0f9b1d61e21e796d78dccdf1352f23cd32812f4850b878ae4944c")

    let instructor = CertificationPageContent.instructor(ana, people: people, lookups: [])
    #expect(
      instructor
        == PersonRowContent(uuid: ana, name: "Ana Diaz", username: "ana", picture: picture))
    let pane = CertificationPageContent(
      try Self.stored(), today: Self.today, courseName: nil, contactName: nil,
      instructor: instructor)
    let row = try #require(pane.rows.first { $0.label == "Instructor" })
    #expect(row.value == "Ana Diaz" && row.link == .person(ana))
    #expect(row.username == "ana" && row.picture == picture)

    // One the people table holds unconnected, or only the lookups name, has no account to show.
    let ben = try #require(UUID(uuidString: "01a0e2ed-1be2-7069-b3e3-7ffb32797bd0"))
    #expect(
      CertificationPageContent.instructor(ben, people: people, lookups: [])
        == PersonRowContent(uuid: ben, name: "Ben Okafor"))
    #expect(
      CertificationPageContent.instructor(
        ana, people: [:], lookups: [PersonLookupItem(ref: .server(ana), name: "Ana Diaz")])
        == PersonRowContent(uuid: ana, name: "Ana Diaz"))
    #expect(CertificationPageContent.instructor(ana, people: [:], lookups: []) == nil)
    #expect(CertificationPageContent.instructor(nil, people: people, lookups: []) == nil)
  }

  @Test func aNameThePhoneDoesNotHoldIsLeftOut() throws {
    let page = CertificationPageContent(
      try Self.stored(), today: Self.today, courseName: nil, contactName: nil, instructor: nil)
    #expect(!page.rows.map(\.label).contains("Course"))
    #expect(!page.rows.map(\.label).contains("Instructor"))
    #expect(!page.rows.map(\.label).contains("Dive center"))
  }

  @Test func aFailedDownloadSaysTheServersSentenceOrTheWebs() {
    #expect(
      CertificationPageContent.downloadFailure(.http(status: 404, message: "No front image"))
        == "No front image")
    #expect(
      CertificationPageContent.downloadFailure(.noRoute)
        == "Failed to download the file. Please try again.")
  }

  // MARK: - The form's slots

  @Test func eachSlotSaysWhatSavingDoesToIt() throws {
    let stored = try #require(try Self.stored().file(side: "front"))
    let pick = CertificationCardPick.framed(Data(count: 2048), side: .front)

    let kept = CertificationCardSlot(side: .front, stored: stored, edit: nil)
    #expect(kept.caption == "card-front.webp · 19 KB" && kept.primary == "Replace")
    #expect(kept.secondary == .remove("Remove the front image"))

    let replaced = CertificationCardSlot(side: .front, stored: stored, edit: .replace(pick))
    #expect(replaced.caption == "Replaces the stored image when you save · 2 KB")
    #expect(replaced.secondary == .discard("Discard the new front image"))

    let added = CertificationCardSlot(side: .back, stored: nil, edit: .replace(pick))
    #expect(added.caption == "Added when you save · 2 KB" && added.primary == "Replace")

    let removed = CertificationCardSlot(side: .front, stored: stored, edit: .remove)
    #expect(removed.caption == "Deleted when you save" && removed.primary == "Upload")
    #expect(removed.shown == .empty && removed.secondary == .keep("Keep the front image"))

    let empty = CertificationCardSlot(side: .back, stored: nil, edit: nil)
    #expect(empty.caption == nil && empty.secondary == nil && empty.primary == "Upload")
    #expect(empty.emptyLabel == "No back image uploaded")
  }

  @Test func aFileOverTenMegabytesIsTooLarge() {
    #expect(!CertificationCardEdits.isTooLarge(10 * 1024 * 1024))
    #expect(CertificationCardEdits.isTooLarge(10 * 1024 * 1024 + 1))
  }

  // MARK: - Framing

  @Test func theFrameIsTheLargestCardShapeThePictureHolds() {
    let wide = CertificationCardCrop(imageWidth: 4000, imageHeight: 1000)
    #expect(wide.area.height == 1000)
    #expect(abs(wide.area.width - 1000 * CertificationCardCrop.aspect) < 0.001)
    #expect(abs(wide.area.x - (4000 - wide.area.width) / 2) < 0.001)

    let tall = CertificationCardCrop(imageWidth: 1000, imageHeight: 3000)
    #expect(tall.area.width == 1000 && tall.area.y > 0)
  }

  @Test func zoomingNarrowsTheFrameWhichNeverLeavesThePicture() {
    var crop = CertificationCardCrop(imageWidth: 3000, imageHeight: 2000)
    crop.setZoom(2)
    #expect(abs(crop.area.width - 1500) < 0.001)
    crop.center(x: 0, y: 99_999)
    #expect(crop.area.x == 0)
    #expect(abs(crop.area.y + crop.area.height - 2000) < 0.001)
    crop.setZoom(10)
    #expect(crop.zoom == CertificationCardCrop.maxZoom)
    crop.setZoom(1)
    #expect(crop.area.x >= 0 && crop.area.x + crop.area.width <= 3000.001)
  }

  @Test func aFramedCardIsKeptNoWiderThanTheWebExportsIt() {
    let big = CertificationCardCrop(imageWidth: 4032, imageHeight: 3024)
    #expect(big.exportSize.width == 1024 && big.exportSize.height == 645)
    let small = CertificationCardCrop(imageWidth: 600, imageHeight: 600)
    #expect(small.exportSize.width == 600)
  }

  private static func decode(files: String, expires: String? = nil) throws -> CertificationRead {
    let json =
      #"{"uuid":"01a0b07a-206e-76bd-bc56-e9646791ba20","agency":"padi","#
      + #""agency_other":null,"name":"Rescue","certification_number":null,"#
      + #""certified_on":null,"expires_on":\#(expires.map { "\"\($0)\"" } ?? "null"),"#
      + #""instructor_number":null,"notes":"","user_uuid":"01a0a51f-afe3-7363-a0bc-b0d634c35923","#
      + #""course_uuid":null,"contact_uuid":null,"instructor_uuid":null,"files":\#(files),"#
      + #""created_at":"2026-09-17T17:46:28.846182Z"}"#
    return try APICoding.decoder().decode(CertificationRead.self, from: Data(json.utf8))
  }
}
