/// `GET /dive-conditions/current`: the surface weather and the sea the instance's provider has for
/// a position at the hour nearest now.
public struct DiveConditionsCurrentRead: Decodable, Hashable, Sendable {
  /// The source line the data's licence asks for, as markdown links.
  public let attribution: String
  /// Nil where the provider has nothing for the position.
  public let weather: ConditionsWeather?
  /// Nil inland, where the marine model has nothing, or where it could not be asked.
  public let sea: ConditionsSea?

  public init(attribution: String, weather: ConditionsWeather?, sea: ConditionsSea? = nil) {
    self.attribution = attribution
    self.weather = weather
    self.sea = sea
  }
}

/// The marine model's sea at an hour, in metric units.
public struct ConditionsSea: Decodable, Hashable, Sendable {
  /// Metres above the model's mean sea level, not a chart datum.
  public let seaLevelHeight: Double?
  /// `high`, `low`, `rising` or `falling`; high or low within half an hour of a turn.
  public let tideState: String?
  /// The last turn of the tide within the day before; nil where none lies there.
  public let previousExtreme: ConditionsExtreme?
  /// The next turn of the tide within the day after; nil where none lies there.
  public let nextExtreme: ConditionsExtreme?
  /// Degrees Celsius.
  public let seaSurfaceTemperature: Double?
  /// Significant wave height, in metres.
  public let waveHeight: Double?
  /// Seconds.
  public let wavePeriod: Double?
  /// Metres.
  public let swellWaveHeight: Double?

  public init(
    seaLevelHeight: Double? = nil, tideState: String? = nil,
    previousExtreme: ConditionsExtreme? = nil, nextExtreme: ConditionsExtreme? = nil,
    seaSurfaceTemperature: Double? = nil, waveHeight: Double? = nil, wavePeriod: Double? = nil,
    swellWaveHeight: Double? = nil
  ) {
    self.seaLevelHeight = seaLevelHeight
    self.tideState = tideState
    self.previousExtreme = previousExtreme
    self.nextExtreme = nextExtreme
    self.seaSurfaceTemperature = seaSurfaceTemperature
    self.waveHeight = waveHeight
    self.wavePeriod = wavePeriod
    self.swellWaveHeight = swellWaveHeight
  }
}

/// A high or low water.
public struct ConditionsExtreme: Decodable, Hashable, Sendable {
  /// `high` or `low`.
  public let kind: String
  /// Spelled at the offset the place has at that instant.
  public let at: DiveTimestamp
  /// Metres above the model's mean sea level.
  public let height: Double

  public init(kind: String, at: DiveTimestamp, height: Double) {
    self.kind = kind
    self.at = at
    self.height = height
  }
}

/// The provider's weather at an hour, in metric units.
public struct ConditionsWeather: Decodable, Hashable, Sendable {
  /// Degrees Celsius, 2 m above ground.
  public let airTemperature: Double?
  /// Percent.
  public let relativeHumidity: Double?
  /// Metres per second, 10 m above ground.
  public let windSpeed: Double?
  /// Where the wind blows from, in degrees.
  public let windDirection: Double?
  /// Metres per second.
  public let windGusts: Double?
  /// Percent.
  public let cloudCover: Double?
  /// Millimetres over the preceding hour.
  public let precipitation: Double?
  /// Reduced to mean sea level, in hectopascals.
  public let pressure: Double?
  /// The WMO 4677 code.
  public let weatherCode: Int?

  public init(
    airTemperature: Double?, relativeHumidity: Double? = nil, windSpeed: Double?,
    windDirection: Double?, windGusts: Double? = nil, cloudCover: Double? = nil,
    precipitation: Double? = nil, pressure: Double? = nil, weatherCode: Int?
  ) {
    self.airTemperature = airTemperature
    self.relativeHumidity = relativeHumidity
    self.windSpeed = windSpeed
    self.windDirection = windDirection
    self.windGusts = windGusts
    self.cloudCover = cloudCover
    self.precipitation = precipitation
    self.pressure = pressure
    self.weatherCode = weatherCode
  }

  /// The dive's `weather` vocabulary value the code means, as the instance fills a dive's: nil for
  /// a code the table does not list.
  public var vocabulary: String? {
    weatherCode.flatMap { Self.vocabularyByCode[$0] }
  }

  // The instance's own table (`services.conditions_derivations`): 1, "mainly clear", is clear
  // because that is what a diver calls a sky with a cloud or two.
  static let vocabularyByCode: [Int: String] = {
    var table: [Int: String] = [0: "clear", 1: "clear", 2: "partly_cloudy", 3: "overcast"]
    for code in [45, 48] { table[code] = "fog" }
    for code in [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82] { table[code] = "rain" }
    for code in [71, 73, 75, 77, 85, 86] { table[code] = "snow" }
    for code in [95, 96, 97, 99] { table[code] = "storm" }
    return table
  }()
}
