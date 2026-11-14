import Foundation

/// What a download archive holds: each computer with its dive count, and when it was downloaded.
public struct DownloadSummary: Codable, Hashable, Sendable {
  public struct Computer: Codable, Hashable, Sendable {
    public var family: DiveComputerFamily
    public var vendor: String
    public var product: String
    public var serial: String
    public var dives: Int

    public init(
      family: DiveComputerFamily, vendor: String, product: String, serial: String, dives: Int
    ) {
      self.family = family
      self.vendor = vendor
      self.product = product
      self.serial = serial
      self.dives = dives
    }

    /// *Shearwater Perdix 3*.
    public var title: String { DiveComputerText.title(vendor: vendor, product: product) }
  }

  public var computers: [Computer]
  public var downloadedAt: Date

  public init(computers: [Computer], downloadedAt: Date) {
    self.computers = computers
    self.downloadedAt = downloadedAt
  }

  public var dives: Int { computers.reduce(0) { $0 + $1.dives } }
}
