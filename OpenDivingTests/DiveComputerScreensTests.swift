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

  @Test func theScreenDraws() async throws {
    let session = try await loaded()
    let inbox = InboxModel(session: session)
    let window = F.window(
      NavigationStack {
        DiveComputerScreen(
          model: DiveComputerModel(
            session: session, inbox: inbox,
            link: LibDCDiveComputerLink(manager: nil, defaults: .standard),
            generator: DiveComputerView.generator))
      }
      .environment(session).environment(inbox))
    defer { window?.isHidden = true }
    #expect(window != nil)
  }

  @Test func theSettingsListDrawsTheAccountsComputers() async throws {
    let session = try await loaded()
    let origin = try #require(session.state.origin)
    let account = try #require(session.user?.uuid)
    try DiveComputerStore(store: session.store, origin: origin, account: account)
      .save(DiveComputerRecord(identity: perdix, lastDownloaded: Date()))
    let model = DiveComputersListModel(session: session)
    #expect(model.computers.map(\.title) == ["Shearwater Perdix 3"])

    let window = F.window(NavigationStack { DiveComputersListView(model: model) })
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
  }
}
