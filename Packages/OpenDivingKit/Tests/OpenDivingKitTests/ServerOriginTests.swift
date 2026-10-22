import Foundation
import OpenDivingKit
import Testing

struct ServerOriginTests {
  @Test(arguments: [
    ("https://opendiving.app/dives", "https://opendiving.app"),
    ("opendiving.app", "https://opendiving.app"),
    ("  HTTPS://OpenDiving.App:443/x?y=1#z ", "https://opendiving.app"),
    ("http://192.168.1.20:8000/api/v1", "http://192.168.1.20:8000"),
    ("http://diving.local:80", "http://diving.local"),
    ("localhost:8000", "https://localhost:8000"),
    ("https://user:secret@opendiving.app/", "https://opendiving.app"),
  ])
  func normalisesWhatWasTypedToItsOrigin(input: String, origin: String) {
    #expect(ServerOrigin(input)?.description == origin)
  }

  @Test(arguments: ["", "   ", "ftp://opendiving.app", "https://", "mailto:diver@example.com"])
  func refusesWhatNamesNoHTTPHost(input: String) {
    #expect(ServerOrigin(input) == nil)
  }

  @Test func readsItsOwnDescriptionBack() throws {
    let origin = try #require(ServerOrigin("http://[::1]:8000"))
    #expect(origin.description == "http://[::1]:8000")
    #expect(ServerOrigin(origin.description) == origin)
  }

  @Test func theSchemeIsPartOfTheServer() {
    #expect(ServerOrigin("http://opendiving.app") != ServerOrigin("https://opendiving.app"))
  }

  @Test func slugIsOnePathComponent() throws {
    #expect(try #require(ServerOrigin("https://opendiving.app")).slug == "https-opendiving.app")
    #expect(try #require(ServerOrigin("http://[::1]:8000")).slug == "http-__1-8000")
  }

  @Test func apiBaseIsTheFixedPrefix() throws {
    let origin = try #require(ServerOrigin("https://opendiving.app/whatever"))
    #expect(origin.apiBaseURL.absoluteString == "https://opendiving.app/api/v1")
  }
}
