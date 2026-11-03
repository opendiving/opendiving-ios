import Testing

@testable import OpenDivingKit

/// Lines as libdivecomputer logs them, most taken from a phone whose Suunto app handshook with
/// the watch.
struct NauticLinkLogTests {
  @Test func aHelloReplyOrAStreamThatAnswered404ShowsAnotherApp() {
    let shown: [String] = [
      "suunto_nautic.c:288 suunto_nautic_recv(): Skipping an unexpected packet (13 0).",
      "suunto_nautic.c:288 suunto_nautic_recv(): Skipping an unexpected packet (13 4211).",
      "suunto_nautic.c:762 suunto_nautic_stream(): "
        + "Failed to unsubscribe from /Logbook/byId/1793610559/Data (status 404).",
    ]
    for line in shown {
      #expect(NauticLinkLog.showsOtherApp(line), "\(line)")
    }
  }

  @Test func otherSkippedPacketsAndFailuresShowNone() {
    let none: [String] = [
      "suunto_nautic.c:288 suunto_nautic_recv(): Skipping an unexpected packet (02 2311).",
      "suunto_nautic.c:288 suunto_nautic_recv(): Skipping an unexpected packet (05 189).",
      "suunto_nautic.c:288 suunto_nautic_recv(): Skipping an unexpected packet (08 2327).",
      "suunto_nautic.c:258 suunto_nautic_recv(): Failed to receive the packet.",
      "suunto_nautic.c:270 suunto_nautic_recv(): Unexpected packet checksum (703bc0c6 b65ee3dc).",
      "suunto_nautic.c:701 suunto_nautic_stream(): "
        + "Failed to receive the stream for /Logbook/byId/1793610559/Data.",
      "suunto_nautic.c:608 suunto_nautic_read_pages(): "
        + "Failed to fetch /Logbook/byId/1793610559/Data (status 404).",
      "suunto_nautic.c:1189 suunto_nautic_download(): "
        + "Failed to download the profile of dive 1793610559.",
      "suunto_nautic.c:757 suunto_nautic_stream(): "
        + "Failed to unsubscribe from /Logbook/byId/1793610559/Data.",
      "suunto_nautic.c:762 suunto_nautic_stream(): "
        + "Failed to unsubscribe from /Logbook/byId/1793610559/Data (status 500).",
    ]
    for line in none {
      #expect(!NauticLinkLog.showsOtherApp(line), "\(line)")
    }
  }

  @Test func aLineItCannotReadShowsNone() {
    let unread: [String] = [
      "",
      "Skipping an unexpected packet (13 ",
      "Skipping an unexpected packet (13 ).",
      "Skipping an unexpected packet (13 x1).",
      "Failed to unsubscribe from",
    ]
    for line in unread {
      #expect(!NauticLinkLog.showsOtherApp(line), "\(line)")
    }
  }
}
