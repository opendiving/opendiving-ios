/// What the Sites map's weather bar draws for the weather at the map's centre: the sky's icon,
/// the air temperature, and the wind's speed with an arrow along it; and, under its tap, the rest
/// of the provider's weather and the sea.
public struct MapWeatherContent: Hashable, Sendable {
  /// A line of the reading the bar has no room for.
  public struct Detail: Hashable, Sendable {
    public let label: String
    /// `16 kn`, `62%`.
    public let value: String
    /// The value as VoiceOver says it, its unit in words.
    public let spokenValue: String
  }

  public let icon: Icon?
  /// `24°C`, whole.
  public let temperature: String?
  /// `11 kn`, whole.
  public let windSpeed: String?
  /// The bearing the wind blows toward, in degrees clockwise from north: the arrow's, which
  /// points where the wind goes as a weather map's does.
  public let windHeading: Double?
  /// `Clear, 21°C, wind from the north-northwest, 7 kn`: the bar in words, as the tap shows it.
  public let summary: String
  /// The summary as VoiceOver says it, its units in words.
  public let accessibilityLabel: String
  /// Gusts, cloud cover, the last hour's rain, humidity and pressure, each where the provider
  /// has it.
  public let details: [Detail]
  /// The sea's temperature, its waves and swell, and the tide with its last and next turn, each
  /// where the marine model has it; empty inland.
  public let sea: [Detail]
  /// The provider's source line, as markdown links.
  public let attribution: String

  /// Nil where the provider has none of the three to show.
  public init?(_ read: DiveConditionsCurrentRead, units: UnitSystem) {
    guard let weather = read.weather else { return nil }
    let vocabulary = weather.vocabulary
    icon = vocabulary.flatMap { Self.icons[$0] }
    temperature = weather.airTemperature.map {
      UnitFormat.temperature($0, units, decimals: 0)
    }
    windSpeed = weather.windSpeed.map { UnitFormat.windSpeed($0) }
    windHeading = weather.windDirection.map {
      (($0 + 180).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }
    guard icon != nil || temperature != nil || windSpeed != nil else { return nil }

    var written: [String] = []
    var spoken: [String] = []
    if let vocabulary {
      written.append(VocabularyLabels.weather(vocabulary))
      spoken.append(VocabularyLabels.weather(vocabulary))
    }
    if let celsius = weather.airTemperature, let temperature {
      written.append(temperature)
      spoken.append(
        UnitFormat.number(celsius, .temperature, units, decimals: 0) + " "
          + Measure.temperature.word(units))
    }
    if let speed = weather.windSpeed, let windSpeed {
      let from = weather.windDirection.map { "wind from the \(Self.spokenPoint($0)), " } ?? "wind "
      written.append(from + windSpeed)
      spoken.append(from + UnitFormat.knots(speed) + " knots")
    }
    summary = Self.sentence(written)
    accessibilityLabel = Self.sentence(spoken)
    details = Self.details(weather, units: units)
    sea = read.sea.map { Self.sea($0, units: units) } ?? []
    attribution = read.attribution
  }

  private static func sea(_ sea: ConditionsSea, units: UnitSystem) -> [Detail] {
    var details: [Detail] = []
    if let celsius = sea.seaSurfaceTemperature {
      details.append(
        Detail(
          label: "Sea temperature", value: UnitFormat.temperature(celsius, units, decimals: 0),
          spokenValue: UnitFormat.number(celsius, .temperature, units, decimals: 0) + " "
            + Measure.temperature.word(units)))
    }
    if let height = sea.waveHeight {
      details.append(length("Wave height", height, units: units))
    }
    if let period = sea.wavePeriod {
      let whole = NumberText.fixed(NumberText.round(period), decimals: 0)
      details.append(
        Detail(label: "Wave period", value: whole + " s", spokenValue: whole + " seconds"))
    }
    if let swell = sea.swellWaveHeight {
      details.append(length("Swell", swell, units: units))
    }
    if let state = sea.tideState, let label = tideStates[state] {
      details.append(Detail(label: "Tide", value: label, spokenValue: label))
    }
    for (extreme, when) in [(sea.previousExtreme, "Last"), (sea.nextExtreme, "Next")] {
      guard let extreme, extreme.kind == "high" || extreme.kind == "low" else { continue }
      let clock = DateText.diveTime(extreme.at)
      details.append(Detail(label: "\(when) \(extreme.kind)", value: clock, spokenValue: clock))
    }
    return details
  }

  private static func length(_ label: String, _ meters: Double, units: UnitSystem) -> Detail {
    Detail(
      label: label, value: UnitFormat.depth(meters, units, decimals: 1),
      spokenValue: UnitFormat.number(meters, .depth, units, decimals: 1) + " "
        + Measure.depth.word(units))
  }

  static let tideStates = [
    "high": "High", "low": "Low", "rising": "Rising", "falling": "Falling",
  ]

  private static func details(_ weather: ConditionsWeather, units: UnitSystem) -> [Detail] {
    var details: [Detail] = []
    if let gusts = weather.windGusts {
      details.append(
        Detail(
          label: "Gusts", value: UnitFormat.windSpeed(gusts),
          spokenValue: UnitFormat.knots(gusts) + " knots"))
    }
    if let cover = weather.cloudCover {
      details.append(percent("Cloud cover", cover))
    }
    if let rain = weather.precipitation {
      details.append(
        Detail(
          label: "Rain, last hour", value: UnitFormat.format(rain, .precipitation, units),
          spokenValue: UnitFormat.number(rain, .precipitation, units) + " "
            + Measure.precipitation.word(units)))
    }
    if let humidity = weather.relativeHumidity {
      details.append(percent("Humidity", humidity))
    }
    if let pressure = weather.pressure {
      let whole = NumberText.fixed(NumberText.round(pressure), decimals: 0)
      details.append(
        Detail(
          label: "Pressure", value: whole + " hPa", spokenValue: whole + " hectopascals"))
    }
    return details
  }

  private static func percent(_ label: String, _ value: Double) -> Detail {
    let whole = NumberText.fixed(NumberText.round(value), decimals: 0)
    return Detail(label: label, value: whole + "%", spokenValue: whole + " percent")
  }

  private static func sentence(_ parts: [String]) -> String {
    let joined = parts.joined(separator: ", ")
    return joined.prefix(1).uppercased() + joined.dropFirst()
  }

  static let icons: [String: Icon] = [
    "clear": .sun, "partly_cloudy": .cloudSun, "overcast": .cloud, "rain": .cloudRain,
    "storm": .cloudLightning, "snow": .cloudSnow, "fog": .cloudFog,
  ]

  /// The nearest of the sixteen compass points to a bearing, in words.
  static func spokenPoint(_ degrees: Double) -> String {
    let points = [
      "north", "north-northeast", "northeast", "east-northeast", "east", "east-southeast",
      "southeast", "south-southeast", "south", "south-southwest", "southwest", "west-southwest",
      "west", "west-northwest", "northwest", "north-northwest",
    ]
    let turned = (degrees.truncatingRemainder(dividingBy: 360) + 360)
      .truncatingRemainder(dividingBy: 360)
    return points[Int(NumberText.round(turned / 22.5)) % 16]
  }
}
