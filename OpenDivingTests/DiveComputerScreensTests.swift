import Foundation
import OpenDivingKit
import SwiftUI
import Testing

@testable import OpenDiving

/// The dive computer screen, the Settings list and a download's inbox row, over a session that
/// has loaded its account.
@MainActor
struct DiveComputerScreensTests {
  private typealias F = OfflineFixtures

  private func loaded() async throws -> Session {
    let session = F.signedIn(
      F.directory(),
      transport: StubTransport { request in F.account(request) ?? F.notFound })
    try await session.loadAccount()
    return session
  }

  private let perdix = DiveComputerIdentity(
    family: .shearwaterPetrel, vendor: "Shearwater", product: "Perdix 3", serial: "D9772626",
    firmware: "93", familyNumber: 0, modelNumber: 14)

  @Test func theScreenDrawsWithAPairedComputer() async throws {
    let session = try await loaded()
    let origin = try #require(session.state.origin)
    let account = try #require(session.user?.uuid)
    try DiveComputerStore(store: session.store, origin: origin, account: account)
      .save(DiveComputerRecord(identity: perdix, lastDownloaded: Date()))
    let inbox = InboxModel(session: session)
    inbox.sessionChanged()
    let window = F.window(
      NavigationStack {
        DiveComputerScreen(
          downloads: DiveComputerDownloads {
            DiveComputerModel(
              session: session, inbox: inbox,
              link: LibDCDiveComputerLink(manager: nil, defaults: .standard),
              positionZones: GeocoderPositionZones(), generator: DiveComputerView.generator)
          })
      }
      .environment(session).environment(inbox))
    defer { window?.isHidden = true }
    #expect(window != nil)
  }

  @Test func theDownloadButtonDrawsEachState() {
    let states: [DiveComputerButtonContent?] = [
      nil,
      .init(ring: .indeterminate, state: .working, accessibilityValue: "Connecting"),
      .init(ring: .indeterminate, state: .working, accessibilityValue: DiveComputerText.busy),
      .init(
        ring: .fraction(0.4), state: .working, accessibilityValue: "Downloading 2 of 5 new dives"),
      .init(ring: .fraction(1), state: .succeeded, accessibilityValue: "2 dives downloaded."),
      .init(ring: .fraction(1), state: .failed, accessibilityValue: "The download failed."),
    ]
    let window = F.window(
      VStack { ForEach(states, id: \.self) { DiveComputerDownloadButtonLabel(content: $0) {} } })
    defer { window?.isHidden = true }
    #expect(window != nil)
  }

  @Test func aComputersPageDraws() {
    let window = F.window(
      NavigationStack {
        DiveComputerPage(record: DiveComputerRecord(identity: perdix, lastDownloaded: Date())) {}
      })
    defer { window?.isHidden = true }
    #expect(window != nil)
  }

  @Test func aDownloadsRowSaysWhatItHolds() {
    let download = InboxDownload(
      computers: [
        .init(
          family: .shearwaterPetrel, vendor: "Shearwater", product: "Perdix 3",
          serial: "D9772626", dives: 12)
      ],
      downloadedAt: Date())
    let file = InboxFile(
      filename: "shearwater-perdix-3_D9772626_2026-10-25T0914.zip", byteSize: 4096,
      download: download)
    #expect(ImportFileRow.title(file) == DiveComputerText.inboxRow(download))
    #expect(ImportFileRow.title(InboxFile(filename: "dive.fit", byteSize: 1)) == "dive.fit")
    #expect(ImportFileRow.removeLabel(file) == "Remove " + DiveComputerText.inboxRow(download))
    #expect(
      ImportFileRow.removeLabel(InboxFile(filename: "dive.fit", byteSize: 1)) == "Remove dive.fit")
  }
}
