/// `GET /dive/{uuid}/recording/{rid}/profile`: the samples. Times are milliseconds and values
/// stay in their integer scales — centimetres for depth and ceiling, hundredths of a degree,
/// seconds for NDL and TTS, hundredths of a bar of ppO₂, tenths of a percent of CNS, whole
/// percent for the gradient factors.
public struct RecordingProfileRead: Codable, Hashable, Sendable {
  /// Milliseconds.
  public let duration: Int
  public let depth: DiveProfileSeries?
  public let ceiling: DiveProfileSeries?
  public let temperature: DiveProfileSeries?
  public let pressures: [DiveProfilePressureSeries]
  public let ndl: DiveProfileSeries?
  public let tts: DiveProfileSeries?
  public let ppo2: DiveProfileSeries?
  public let cns: DiveProfileSeries?
  public let gradientFactor: DiveProfileSeries?
  public let surfaceGradientFactor: DiveProfileSeries?
  public let events: [DiveProfileEvent]
  /// `file`, `divejson_import` or `merge`.
  public let provenance: String
  /// Where the dive ends on this axis, in milliseconds, short of `duration`; nothing is cut
  /// to it.
  public let diveEndTime: Int?
}
