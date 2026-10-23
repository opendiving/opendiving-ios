import OpenDivingKit
import Testing

struct LocalNetworkTests {
  @Test(arguments: [
    ("http://192.168.1.20:8000", true),
    ("http://10.0.0.5", true),
    ("http://172.20.1.1", true),
    ("http://172.32.0.1", false),
    ("http://169.254.3.4", true),
    ("http://mac-mini.local:8000", true),
    ("http://nas:8000", true),
    ("http://[fe80::1]:8000", true),
    ("http://[fd12:3456::1]", true),
    ("http://localhost:8000", false),
    ("http://api.localhost", false),
    ("http://127.0.0.1:8000", false),
    ("http://[::1]:8000", false),
    ("https://opendiving.app", false),
    ("http://8.8.8.8", false),
  ])
  func localNetwork(input: String, expected: Bool) throws {
    #expect(try #require(ServerOrigin(input)).isLocalNetwork == expected)
  }

  @Test func onlyHTTPSIsEncrypted() {
    #expect(ServerOrigin("https://opendiving.app")!.isEncrypted)
    #expect(!ServerOrigin("http://192.168.1.20:8000")!.isEncrypted)
  }
}
