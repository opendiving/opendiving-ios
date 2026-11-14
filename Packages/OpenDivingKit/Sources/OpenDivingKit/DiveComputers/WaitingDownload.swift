import Foundation

/// One download *Waiting to Sync* lists: *3 dives from Shearwater Perdix 3* over where it stands
/// — waiting to upload, the server's sentence where it refused the archive with one, or the time
/// zone its dives wait for.
public struct WaitingDownload: Hashable, Sendable, Identifiable {
  public let id: UUID
  public let title: String
  public let stage: String
  /// The stage is why the archive is not sent by itself.
  public let refused: Bool
  /// The archive the row is, which *Upload* sends again and *Remove* removes; nil for dives
  /// held for a zone, which the Dive Computers screen asks about.
  public let archive: DownloadArchive?

  /// The engine's archives, then its held dives, each oldest first.
  public static func rows(
    archives: [DownloadArchive], held: [DiveComputerEngine.HeldDives]
  ) -> [WaitingDownload] {
    archives.map { archive in
      let computer = archive.summary.computers.first?.title ?? ""
      let stage: String
      switch archive.refusal {
      case .none, .server(message: nil): stage = DiveComputerText.waitingToUploadStage
      case .server(message: let message?): stage = message
      case .notAppliedAtOnce: stage = DiveComputerText.needsNewerServer
      }
      return WaitingDownload(
        id: archive.id, title: DiveComputerText.fromComputer(archive.summary.dives, computer),
        stage: stage, refused: stage != DiveComputerText.waitingToUploadStage, archive: archive)
    }
      + held.map { held in
        WaitingDownload(
          id: held.id, title: DiveComputerText.fromComputer(held.dives, held.computer),
          stage: DiveComputerText.chooseTimeZone(held.dives), refused: false, archive: nil)
      }
  }
}
