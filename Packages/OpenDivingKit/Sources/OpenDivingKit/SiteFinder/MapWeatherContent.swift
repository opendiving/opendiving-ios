/// What the Sites map's weather bar draws for the weather at the map's centre: the sky's icon,
/// the air temperature, and the wind's speed with an arrow along it.
public struct MapWeatherContent: Hashable, Sendable {
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
    attribution = read.attribution
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
