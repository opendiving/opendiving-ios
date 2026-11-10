import Foundation
import Testing

@testable import OpenDivingKit

/// What the list's cards, a certification's page and the form's slots are given, in the web's
/// words, and the framing's geometry.
struct CertificationContentTests {
  private static let today = CalendarDate(year: 2026, month: 11, day: 10)!

  private static func stored() throws -> CertificationRead {
    try KitFixture.decode(CertificationRead.self, "certification-front-only")
  }

  // MARK: - File sizes, the web's golden rows

  @Test func aFileSizeReadsAsTheWebWritesIt() {
    #expect(FileSizeText.size(0) == "0 KB")
    #expect(FileSizeText.size(1) == "1 KB")
    #expect(FileSizeText.size(400) == "1 KB")
    #expect(FileSizeText.size(1024) == "1 KB")
    #expect(FileSizeText.size(500 * 1024) == "500 KB")
    #expect(FileSizeText.size(1024 * 1024) == "1.0 MB")
    #expect(FileSizeText.size(1024 * 1024 - 1).hasSuffix("KB"))
    #expect(FileSizeText.size(5 * 1024 * 1024 / 2) == "2.5 MB")
    #expect(FileSizeText.size(5 * 1024 * 1024) == "5.0 MB")
    #expect(FileSizeText.size(1024 * 1024 * 1024) == "1.0 GB")
  }

  // MARK: - The list's card

  @Test func aCardCarriesItsLevelAgencyFiguresAndFront() throws {
    let card = CertificationCardContent(try Self.stored(), today: Self.today)
    #expect(card.name == "Solo Diver" && card.agency == "SDI")
    #expect(
      card.figures == [
        Figure(label: "Number", value: "0000000"),
        Figure(label: "Certified", value: "Sep 25, 2025"),
      ])
    #expect(card.front?.side == "front" && card.expiry == nil)
    #expect(card.missingFrontIcon == .tabImageOff)
  }

  @Test func aCardWithNoFrontOrAPDFDrawsItsIcon() throws {
    let bare = try Self.decode(files: "[]", expires: "2026-12-01")
    let card = CertificationCardContent(bare, today: Self.today)
    #expect(card.front == nil && card.missingFrontIcon == .tabBadgeCheck)
    #expect(card.expiry == .expiringSoon)

    let pdf = try Self.decode(
      files: #"[{"uuid":"01a0b07a-2e5b-792f-b35b-98009ab92953","side":"front","#
        + #""content_type":"application/pdf","byte_size":10,"original_filename":"c.pdf"}]"#)
    let pdfCard = CertificationCardContent(pdf, today: Self.today)
    #expect(pdfCard.front == nil && pdfCard.missingFrontIcon == .tabFileText)
  }

  // MARK: - The page

  @Test func thePageListsTheDialogsRowsInOrderLinkingTheCourseAndInstructor() throws {
    let certification = try Self.stored()
    let page = CertificationPageContent(
      certification, today: Self.today, courseName: "Solo course", contactName: "Blue Ocean",
      instructorName: "Kim")
    #expect(
      page.rows.map(\.label) == [
        "Certification number", "Course", "Certified on", "Dive center", "Instructor",
        "Instructor number",
      ])
    #expect(page.rows[1].link == .course(certification.courseUuid!))
    #expect(page.rows[4].link == .person(certification.instructorUuid!))
    #expect(page.sides.map(\.title) == ["Front", "Back"])
    #expect(page.sides[0].file != nil && page.sides[1].file == nil)
    #expect(page.notes == nil)
  }

  @Test func aNameThePhoneDoesNotHoldIsLeftOut() throws {
    let page = CertificationPageContent(
      try Self.stored(), today: Self.today, courseName: nil, contactName: nil, instructorName: nil)
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
