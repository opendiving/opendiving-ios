import Foundation
import Testing

@testable import OpenDivingKit

/// An address read into a server and a target, and what the app does with it by where it came
/// from and the session's state.
@MainActor
struct AppLinkTests {
  private static let uuid = UUID(uuidString: "01a0a51f-afe3-7363-a0bc-b0d634c35924")!
  private static let server = ServerOrigin("https://dive.example.org")!
  private static let other = ServerOrigin("https://opendiving.app")!

  private func link(_ address: String) -> AppLink? {
    AppLink(URL(string: address)!)
  }

  @Test func everyRecordPageIsReadByItsDirectory() {
    let uuid = Self.uuid
    let rows: [(String, AppLink.Record)] = [
      ("sites", .site(uuid)), ("dives", .dive(uuid)), ("trips", .trip(uuid)),
      ("people", .person(uuid)), ("gear", .gearItem(uuid)), ("courses", .course(uuid)),
      ("species", .species(uuid)), ("import", .importPage(uuid)),
    ]
    for (directory, record) in rows {
      #expect(
        link("https://dive.example.org/\(directory)/\(APIClient.wire(uuid))")
          == AppLink(origin: Self.server, target: .record(record)))
    }
  }

  @Test func aConnectLinkIsItsTokenByTheAPIsPattern() {
    #expect(
      link("https://dive.example.org/connect/9f86d081-884c")?.target
        == .connect(token: "9f86d081-884c"))
    #expect(link("https://dive.example.org/connect/" + String(repeating: "a", count: 32)) != nil)
    #expect(link("https://dive.example.org/connect/" + String(repeating: "a", count: 33)) == nil)
    #expect(link("https://dive.example.org/connect/ABC") == nil)
    #expect(link("https://dive.example.org/connect/a_b") == nil)
    #expect(link("https://dive.example.org/connect/a%2Fb") == nil)
    #expect(link("https://dive.example.org/connect/abc/def") == nil)
    #expect(link("https://dive.example.org/connect") == nil)
  }

  @Test func aSignInLinkNeedsATokenThatIsNotEmpty() {
    #expect(
      link("https://dive.example.org/auth/verify?token=t0k3n")?.target == .signIn(token: "t0k3n"))
    #expect(
      link("https://dive.example.org/auth/verify/?next=/dives&token=t0k3n")?.target
        == .signIn(token: "t0k3n"))
    #expect(link("https://dive.example.org/auth/verify?token=") == nil)
    #expect(link("https://dive.example.org/auth/verify") == nil)
    #expect(link("https://dive.example.org/auth/verify?code=t0k3n") == nil)
  }

  @Test func onlyThePathAndTheTokenAreRead() {
    let wire = APIClient.wire(Self.uuid)
    let dive = AppLink(origin: Self.server, target: .record(.dive(Self.uuid)))
    #expect(link("https://dive.example.org/dives/\(wire)/") == dive)
    #expect(link("https://dive.example.org/dives/\(wire.uppercased())") == dive)
    #expect(link("https://dive.example.org/dives/\(wire)?tab=data&from=mail#gear") == dive)
    #expect(link("HTTPS://Dive.Example.org/dives/\(wire)") == dive)
    #expect(
      link("http://localhost:3000/dives/\(wire)")?.origin == ServerOrigin("http://localhost:3000"))
    #expect(link("https://dive.example.org:443/dives/\(wire)")?.origin == Self.server)
  }

  @Test func whatIsNoLinkReadsAsNone() {
    let wire = APIClient.wire(Self.uuid)
    for address in [
      "https://dive.example.org/", "https://dive.example.org", "https://dive.example.org/dives",
      "https://dive.example.org/dives/new", "https://dive.example.org/dives/\(wire)/edit",
      "https://dive.example.org/import/\(wire)/log", "https://dive.example.org/sites/proposals",
      "https://dive.example.org/settings/notifications", "https://dive.example.org/dives//\(wire)",
      "https://dive.example.org/dives/\(wire)//", "https://dive.example.org/Dives/\(wire)",
      "https://dive.example.org/checkin/\(wire)", "ftp://dive.example.org/dives/\(wire)",
      "mailto:diver@example.com", "https://example.com/",
    ] {
      #expect(link(address) == nil, "\(address)")
    }
  }

  @Test func givenTextIsReadOnceTrimmedAndOnlyWithAScheme() {
    #expect(AppLink.url(given: "  https://dive.example.org/connect/abc\n")?.path == "/connect/abc")
    #expect(AppLink.url(given: "dive.example.org/connect/abc") == nil)
    #expect(AppLink.url(given: "hello there") == nil)
    #expect(AppLink.url(given: "") == nil)
  }

  // MARK: - What the app does

  private func action(
    _ address: String, _ source: AppLinkRouter.Source, _ state: Session.State
  ) -> AppLinkRouter.Action {
    AppLinkRouter.action(for: URL(string: address)!, from: source, state: state)
  }

  @Test func aRecordOrAConnectLinkOpensSignedInOnItsServer() {
    let signedIn = Session.State.signedIn(Self.server)
    let dive = "https://dive.example.org/dives/\(APIClient.wire(Self.uuid))"
    let connect = "https://dive.example.org/connect/abc"
    for source in [AppLinkRouter.Source.outside, .given] {
      #expect(action(dive, source, signedIn) == .open(.record(.dive(Self.uuid))))
      #expect(action(connect, source, signedIn) == .open(.connect(token: "abc")))
    }
  }

  @Test func whatIsNotActedOnFromOutsideGoesToTheBrowser() {
    let dive = "https://dive.example.org/dives/\(APIClient.wire(Self.uuid))"
    let signIn = "https://dive.example.org/auth/verify?token=t"
    let rows: [(String, Session.State)] = [
      // Signed out on the server: held, then redeemed, once the sign-in screens can.
      (dive, .signingIn(Self.server)),
      ("https://dive.example.org/connect/abc", .signingIn(Self.server)),
      (signIn, .signingIn(Self.server)),
      (signIn, .signedIn(Self.server)),
      (dive, .signedIn(Self.other)),
      (dive, .signingIn(Self.other)),
      (dive, .noServer),
      ("https://dive.example.org/dives/new", .signedIn(Self.server)),
      ("https://example.com/", .signedIn(Self.server)),
    ]
    for (address, state) in rows {
      #expect(action(address, .outside, state) == .browser(URL(string: address)!), "\(address)")
    }
  }

  @Test func whatIsNotActedOnWhenGivenIsAnswered() {
    let dive = "https://dive.example.org/dives/\(APIClient.wire(Self.uuid))"
    let url = URL(string: dive)!
    let answer = action(dive, .given, .signedIn(Self.other))
    #expect(answer == .answer(.otherServer(Self.server, current: Self.other, url: url)))
    if case .answer(let given) = answer {
      #expect(given.browser == url)
      #expect(
        given.sentence
          == "This link is for https://dive.example.org, and the app is on https://opendiving.app.")
    }
    #expect(
      action(dive, .given, .noServer)
        == .answer(.otherServer(Self.server, current: nil, url: url)))

    let notALink = action("https://example.com/", .given, .signedIn(Self.server))
    #expect(notALink == .answer(.notALink))
    #expect(action("https://dive.example.org/dives/new", .given, .signedIn(Self.server)) == notALink)

    let signIn = "https://dive.example.org/auth/verify?token=t"
    #expect(action(signIn, .given, .signedIn(Self.server)) == .answer(.signedInAlready))
    #expect(action(signIn, .given, .signingIn(Self.server)) == .answer(.signInWithTheCode))
    #expect(action(dive, .given, .signingIn(Self.server)) == .answer(.signInFirst))

    for answer in [GivenLinkAnswer.notALink, .signedInAlready, .signInFirst, .signInWithTheCode] {
      #expect(answer.browser == nil)
    }
  }

  // MARK: - The presenter

  @Test func aLinkFromOutsideOpensOrComesBackForTheBrowser() {
    let presenter = ScreenPresenter()
    let dive = URL(string: "https://dive.example.org/dives/\(APIClient.wire(Self.uuid))")!
    #expect(presenter.receive(dive, state: .signedIn(Self.server)) == nil)
    #expect(presenter.opened?.screen == .link(.record(.dive(Self.uuid))))

    let first = presenter.opened
    #expect(presenter.receive(dive, state: .signedIn(Self.other)) == dive)
    #expect(presenter.opened == first)
  }

  @Test func aNotificationsScreenAndALinksReplaceEachOther() {
    let presenter = ScreenPresenter()
    presenter.open(.diveComputers)
    #expect(presenter.opened?.screen == .notice(.diveComputers))
    presenter.open(.connect(token: "abc"))
    #expect(presenter.opened?.screen == .link(.connect(token: "abc")))
    presenter.open(.dive(Self.uuid))
    #expect(presenter.opened?.screen == .notice(.dive(Self.uuid)))
  }

  @Test func theLaunchsLinkIsTakenOnce() {
    let url = URL(string: "https://dive.example.org/connect/abc")!
    let presenter = ScreenPresenter(launchLink: url)
    #expect(presenter.takeLaunchLink() == url)
    #expect(presenter.takeLaunchLink() == nil)
  }
}
