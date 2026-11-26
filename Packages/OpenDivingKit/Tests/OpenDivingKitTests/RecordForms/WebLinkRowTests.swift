import Foundation
import Testing

@testable import OpenDivingKit

/// A record's links: the rows a form holds, the list a write sends, and what a read takes.
struct WebLinkRowTests {
  private func urlIssues(_ url: String) -> [FormIssue] {
    PersonFormValues(name: "Sam", links: [WebLinkRow(url: url)]).issues
  }

  @Test func theListIsSentTrimmedSchemedAndFolded() throws {
    let values = PersonFormValues(
      name: "Sam",
      links: [
        WebLinkRow(url: " sam.example ", label: "  "),
        WebLinkRow(url: "", label: ""),
        WebLinkRow(url: "https://sam.example", label: "Again"),
        WebLinkRow(url: "HTTP://Photos.example/sam", label: " Photos "),
      ])
    #expect(values.issues.isEmpty)
    #expect(
      try values.toCreate().links == [
        WebLink(url: "https://sam.example"),
        WebLink(url: "HTTP://Photos.example/sam", label: "Photos"),
      ])
  }

  @Test(arguments: [
    "ftp://sam.example", "https://", "https:///path", "https://[::1/", "https://sam.example/a b",
    "https://sam.example/a\u{85}b", "https://sam.example/a\u{1C}b", "https://sam.example/a\u{1F}b",
    "https://sam.example/a\u{A0}b", "https://sam.example/a\u{FEFF}b",
    "https://sam.example/a\u{2007}b", "https://sam.example/a\u{3000}b",
    "\u{FEFF}https://sam.example",
  ])
  func anAddressTheAPIRefusesIsAnIssue(url: String) {
    #expect(
      urlIssues(url) == [
        FormIssue(
          field: "links", index: 0, member: "url", message: "Use a web address, e.g. blueocean.com")
      ], "\(url.unicodeScalars.map { String($0.value, radix: 16) })")
  }

  @Test(arguments: [
    "https://sam.example", "http://sam.example:8080/a?b#c", "HTTPS://SAM.EXAMPLE",
    "https://[::1]/", "https://sam.example/\u{200B}",
  ])
  func anAddressTheAPITakesPasses(url: String) {
    #expect(urlIssues(url).isEmpty, "\(url)")
  }

  @Test func aLabelNeedsItsAddressAndFitsTheBound() {
    var values = PersonFormValues(name: "Sam", links: [WebLinkRow(url: " ", label: "Blog")])
    #expect(
      values.issues == [
        FormIssue(
          field: "links", index: 0, member: "url", message: "Add the address this label is for")
      ])
    values.links[0] = WebLinkRow(url: "sam.example", label: String(repeating: "a", count: 121))
    #expect(
      values.issues == [
        FormIssue(
          field: "links", index: 0, member: "label",
          message: "Label cannot exceed 120 characters")
      ])
  }

  @Test func aRecordKeepsAtMostTwentyLinks() {
    let twenty = (1...20).map { WebLinkRow(url: "https://\($0).example") }
    #expect(!WebLinkRow.canAdd(to: twenty))
    #expect(WebLinkRow.canAdd(to: Array(twenty.dropLast())))
    var values = TripFormValues(name: "Red Sea", links: twenty)
    #expect(values.issues.isEmpty)
    values.links.append(WebLinkRow(url: "https://21.example"))
    #expect(
      values.issues == [FormIssue(field: "links", message: "A record keeps at most 20 links")])
    values.links[20].url = "https://1.example"
    #expect(values.issues.isEmpty)
  }

  /// The API digests a create's raw body for its idempotency key, and a queued body is encoded
  /// again when it is sent: a create with no links has to encode as the previous build's did.
  @Test func aCreateWithNoLinksEncodesNoKeyForThem() throws {
    let encoder = APICoding.requestEncoder()
    let bodies: [any Encodable] = [
      try ContactFormValues(name: "Blue Ocean").toCreate(),
      try PersonFormValues(name: "Sam", links: [WebLinkRow()]).toCreate(),
      try CourseFormValues(name: "AOW").toCreate(),
      try GearItemFormValues(name: "Fins").toCreate(),
      try TripFormValues(name: "Red Sea").toCreate(),
    ]
    for body in bodies {
      let json = try #require(
        JSONSerialization.jsonObject(with: encoder.encode(body)) as? [String: Any])
      #expect(json["links"] == nil, "\(type(of: body))")
    }
  }

  @Test func anUpdateSendsTheWholeListOnlyWhenItChanged() throws {
    let baseline = CourseFormValues(
      name: "AOW", links: [WebLinkRow(url: "https://a.example"), WebLinkRow(url: "b.example")])
    var reordered = baseline
    reordered.links.reverse()
    #expect(try baseline.diff(from: baseline).links == nil)
    var relabelledBlank = baseline
    relabelledBlank.links[0].label = "  "
    #expect(try relabelledBlank.diff(from: baseline).isEmpty)
    #expect(
      try reordered.diff(from: baseline).links == [
        WebLink(url: "https://b.example"), WebLink(url: "https://a.example"),
      ])
    var cleared = baseline
    cleared.links = []
    #expect(try cleared.diff(from: baseline).links == [])
    let encoded = try APICoding.requestEncoder().encode(try cleared.diff(from: baseline))
    let json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    #expect((json["links"] as? [Any])?.isEmpty == true)
  }

  @Test func eachFormDiffsAndLaysOverItsLinks() throws {
    let links = [WebLinkRow(url: "https://x.example", label: "X")]
    let sent = [WebLink(url: "https://x.example", label: "X")]

    let contact = try ContactFormValues(name: "C", links: links).diff(
      from: ContactFormValues(name: "C"))
    #expect(contact.links == sent)
    #expect(ContactFormValues(name: "C").applying(contact).links == links)

    let person = try PersonFormValues(name: "P", links: links).diff(
      from: PersonFormValues(name: "P"))
    #expect(person.links == sent)
    #expect(PersonFormValues(name: "P").applying(person).links == links)

    let gear = try GearItemFormValues(name: "G", links: links).diff(
      from: GearItemFormValues(name: "G"))
    #expect(gear.links == sent)
    #expect(GearItemFormValues(name: "G").applying(gear).links == links)
    #expect(try GearItemFormValues(name: "G").diff(from: GearItemFormValues(name: "G")).isEmpty)

    let trip = try TripFormValues(name: "T", links: links).diff(from: TripFormValues(name: "T"))
    #expect(trip.links == sent)
    #expect(TripFormValues(name: "T").applying(trip).links == links)
  }

  @Test func aReadWithoutLinksHasNone() throws {
    var contact =
      try JSONSerialization.jsonObject(with: KitFixture.data("contact"))
      as! [String: Any]
    contact.removeValue(forKey: "links")
    let read = try APICoding.decoder().decode(
      ContactRead.self, from: JSONSerialization.data(withJSONObject: contact))
    #expect(read.links.isEmpty)
  }

  @Test func aPageShowsTheLabelOrTheAddressWithoutItsScheme() {
    #expect(
      ShownLink.list([
        WebLink(url: "https://blueocean.example/booking", label: "Booking"),
        WebLink(url: "https://blueocean.example/"),
        WebLink(url: "https://blueocean.example/dahab", label: " "),
      ]) == [
        ShownLink(text: "Booking", url: URL(string: "https://blueocean.example/booking")),
        ShownLink(text: "blueocean.example", url: URL(string: "https://blueocean.example/")),
        ShownLink(
          text: "blueocean.example/dahab", url: URL(string: "https://blueocean.example/dahab")),
      ])
  }
}
