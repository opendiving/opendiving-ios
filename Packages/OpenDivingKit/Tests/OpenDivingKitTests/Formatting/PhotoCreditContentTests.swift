import Foundation
import OpenDivingKit
import Testing

/// The credit has the web's `SpeciesPhotoCredit` parts, the author alone on the first line.
struct PhotoCreditContentTests {
  private func species(_ edit: (inout [String: Any]) -> Void = { _ in }) throws -> SpeciesRead {
    var object =
      try JSONSerialization.jsonObject(with: KitFixture.data("species")) as! [String: Any]
    edit(&object)
    return try APICoding.decoder().decode(
      SpeciesRead.self, from: JSONSerialization.data(withJSONObject: object))
  }

  @Test func theAuthorIsOneLineAndTheLicenceThenTheSourceTheNext() throws {
    let credit = try #require(PhotoCreditContent.species(species()))
    #expect(credit.text == "Photo by Jane Doe\nCC BY-SA 4.0 · Wikimedia Commons")
    #expect(
      credit.runs.compactMap(\.url) == [
        URL(string: "https://creativecommons.org/licenses/by-sa/4.0")!,
        URL(
          string:
            "https://commons.wikimedia.org/wiki/File:Amphiprion%20bicinctus%20Red%20Sea.jpg")!,
      ])
    #expect(credit.runs.first { $0.text == "CC BY-SA 4.0" }?.url != nil)
  }

  @Test func eachPartIsDrawnOnlyWhenItIsThere() throws {
    let noAuthor = try #require(
      PhotoCreditContent.species(species { $0["photo_author"] = NSNull() }))
    #expect(noAuthor.text == "Photo\nCC BY-SA 4.0 · Wikimedia Commons")

    let unlinkedLicence = try #require(
      PhotoCreditContent.species(species { $0["photo_license_url"] = NSNull() }))
    #expect(unlinkedLicence.runs.first { $0.text == "CC BY-SA 4.0" }?.url == nil)

    let noLicence = try #require(
      PhotoCreditContent.species(species { $0["photo_license"] = "" }))
    #expect(noLicence.text == "Photo by Jane Doe\nWikimedia Commons")

    let noSource = try #require(
      PhotoCreditContent.species(species { $0["photo_source_url"] = NSNull() }))
    #expect(noSource.text == "Photo by Jane Doe\nCC BY-SA 4.0")
  }

  @Test func noPhotoOrNothingRecordedIsNoLine() throws {
    let noPhoto = try species { $0["photo_sha256"] = NSNull() }
    #expect(PhotoCreditContent.species(noPhoto) == nil)
    let bare = try species {
      $0["photo_author"] = NSNull()
      $0["photo_license"] = ""
      $0["photo_source_url"] = NSNull()
    }
    #expect(PhotoCreditContent.species(bare) == nil)
  }
}
