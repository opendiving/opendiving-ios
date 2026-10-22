import Foundation

/// One computer's record of a dive. Ordinal 0 is the primary, whose profile is "the" profile.
public struct RecordingRead: Codable, Hashable, Sendable {
  public let uuid: UUID
  public let ordinal: Int
  public let device: RecordingDevice?
  /// The mode the device ran in, as the API sent it; null means not recorded.
  public let mode: String?
  public let decoModel: RecordingDecoModel?
  /// The water density the device was set to, as the API sent it.
  public let salinity: String?
  /// This device's own start; the profile's times count from it.
  public let startedAt: DiveTimestamp?
  public let files: [DiveFileInfo]
  public let profile: DiveProfileInfo?
  public let updatedAt: DiveTimestamp?
  /// Percent.
  public let cnsStart: Double?
  public let cnsEnd: Double?
  public let otuStart: Double?
  public let otuEnd: Double?
  /// Bar.
  public let surfacePressureBar: Double?
}
