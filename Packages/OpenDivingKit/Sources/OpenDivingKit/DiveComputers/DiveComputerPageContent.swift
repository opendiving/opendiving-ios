import Foundation

/// What a paired computer's page shows of its record, in a fixed order, leaving out what the
/// computer has not reported.
public struct DiveComputerPageContent: Hashable, Sendable {
  public struct Fact: Hashable, Sendable, Identifiable {
    public let label: String
    public let value: String

    public var id: String { label }
  }

  /// *Shearwater Perdix 3*.
  public let title: String
  public let facts: [Fact]

  /// `zone` is the phone's, which the *Last downloaded* day is printed in.
  public init(_ record: DiveComputerRecord, in zone: TimeZone = .current) {
    title = record.title
    let values: [(String, String?)] = [
      (DiveComputerText.serialLabel, record.serial),
      (DiveComputerText.hardwareLabel, record.hardware),
      (DiveComputerText.firmwareLabel, record.firmware),
      (
        DiveComputerText.lastDownloadedLabel,
        record.lastDownloaded.map {
          DiveComputerText.day($0, in: zone)
        }
      ),
    ]
    facts = values.compactMap { label, value in
      guard let value, !value.isEmpty else { return nil }
      return Fact(label: label, value: value)
    }
  }
}
