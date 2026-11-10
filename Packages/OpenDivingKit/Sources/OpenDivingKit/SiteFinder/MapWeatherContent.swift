/// What the Sites map's weather bar draws for the weather at a site: the sky's icon, the air
/// temperature, and the wind's speed with an arrow along it; and, under its tap, the rest of the
/// provider's weather and the sea.
public struct MapWeatherContent: Hashable, Sendable {
  /// A line of the reading the bar has no room for.
  public struct Detail: Hashable, Sendable {
    public let label: String
    /// `16 kn`, `62%`.
    public let value: String
    /// The value as VoiceOver says it, its unit in words.
    public let spokenValue: String
  }

  /// The sky's icon as layers drawn one over another, each in its own tone: a cloud with a sun or
  /// with rain is drawn as its parts, so only the sun and the drops take a colour. Empty for a sky
  /// the provider gave no code for that the table lists.
  public let sky: [IconLayer]
  /// `24°C`, whole.
  public let temperature: String?
  /// `11 kn`, whole.
  public let windSpeed: String?
  /// The bearing the wind blows toward, in degrees clockwise from north: the arrow's, which
  /// points where the wind goes as a weather map's does.
  public let windHeading: Double?
  /// `Clear, 21 degrees Celsius, wind from the north-northwest, 7 knots, sea 26 degrees Celsius`:
  /// the bar as VoiceOver says it, the wind's direction, which the arrow draws, in words.
  public let accessibilityLabel: String
  /// Gusts, cloud cover, the last hour's rain, humidity and pressure, each where the provider
  /// has it.
  public let details: [Detail]
  /// The sea's surface temperature, `26°C`, which the card shows large beside the sky and the wind.
  public let seaTemperature: Detail?
  /// The tide with its last and next turn where ``tide`` cannot draw it, and a wave period with no
  /// height to draw it on, each where the marine model has it; empty inland.
  public let sea: [Detail]
  /// The waves and swell drawn on one scale; nil without either height.
  public let waves: WaveProfile?
  /// The tide drawn from the turn before the hour to the turn after; nil without both.
  public let tide: TideCurve?
  /// The provider's source line, as markdown links.
  public let attribution: String

  /// Nil where the provider has none of the three to show.
  public init?(_ read: DiveConditionsCurrentRead, units: UnitSystem) {
    guard let weather = read.weather else { return nil }
    let vocabulary = weather.vocabulary
    sky = vocabulary.flatMap { Self.skies[$0] } ?? []
    temperature = weather.airTemperature.map {
      UnitFormat.temperature($0, units, decimals: 0)
    }
    windSpeed = weather.windSpeed.map { UnitFormat.windSpeed($0) }
    windHeading = weather.windDirection.map {
      (($0 + 180).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }
    guard !sky.isEmpty || temperature != nil || windSpeed != nil else { return nil }

    var spoken: [String] = []
    if let vocabulary {
      spoken.append(VocabularyLabels.weather(vocabulary))
    }
    if let celsius = weather.airTemperature {
      spoken.append(
        UnitFormat.number(celsius, .temperature, units, decimals: 0) + " "
          + Measure.temperature.word(units))
    }
    if let speed = weather.windSpeed {
      let from = weather.windDirection.map { "wind from the \(Self.spokenPoint($0)), " } ?? "wind "
      spoken.append(from + UnitFormat.knots(speed) + " knots")
    }
    details = Self.details(weather, units: units)
    let drawnTide = read.sea.flatMap { Self.tide($0, now: read.at) }
    let drawnWaves = read.sea.flatMap { WaveProfile($0, units: units) }
    tide = drawnTide
    waves = drawnWaves
    seaTemperature = read.sea?.seaSurfaceTemperature.map { celsius in
      Detail(
        label: "Sea temperature", value: UnitFormat.temperature(celsius, units, decimals: 0),
        spokenValue: UnitFormat.number(celsius, .temperature, units, decimals: 0) + " "
          + Measure.temperature.word(units))
    }
    if let sea = seaTemperature {
      spoken.append("sea " + sea.spokenValue)
    }
    accessibilityLabel = Self.sentence(spoken)
    sea =
      read.sea.map {
        Self.sea($0, units: units, drawsTide: drawnTide != nil)
      } ?? []
    attribution = read.attribution
  }

  private static func sea(_ sea: ConditionsSea, units: UnitSystem, drawsTide: Bool) -> [Detail] {
    var details: [Detail] = []
    // A period with no height has no strip to read on.
    if sea.waveHeight == nil, let period = sea.wavePeriod {
      let whole = NumberText.fixed(NumberText.round(period), decimals: 0)
      details.append(
        Detail(label: "Wave period", value: whole + " s", spokenValue: whole + " seconds"))
    }
    guard !drawsTide else { return details }
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

  private static func tide(_ sea: ConditionsSea, now: DiveTimestamp?) -> TideCurve? {
    guard let previous = sea.previousExtreme, let next = sea.nextExtreme else { return nil }
    return TideCurve(previous: previous, next: next, now: now, state: sea.tideState)
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
      // Inches keep two places so a light shower shows, but no rain is `0 in`, not `0.00 in`.
      let none = NumberText.round(Measure.precipitation.toDisplay(rain, units), decimals: 2) == 0
      let number = none ? "0" : UnitFormat.number(rain, .precipitation, units)
      details.append(
        Detail(
          label: "Rain, last hour",
          value: number + Measure.precipitation.separator + Measure.precipitation.label(units),
          spokenValue: number + " " + Measure.precipitation.word(units)))
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

  /// A colour the bar's icons are drawn in, which the app names.
  public enum Tone: Hashable, Sendable {
    case sun, water
  }

  /// One symbol of an icon drawn in layers, and its tone; nil, the text's colour.
  public struct IconLayer: Hashable, Sendable {
    public let icon: Icon
    public let tone: Tone?

    init(_ icon: Icon, _ tone: Tone? = nil) {
      self.icon = icon
      self.tone = tone
    }
  }

  static let skies: [String: [IconLayer]] = [
    "clear": [IconLayer(.sun, .sun)],
    "partly_cloudy": [IconLayer(.cloudSunSun, .sun), IconLayer(.cloudSunCloud)],
    "overcast": [IconLayer(.cloud)],
    "rain": [IconLayer(.cloudRainCloud), IconLayer(.cloudRainDrops, .water)],
    "storm": [IconLayer(.cloudLightning)],
    "snow": [IconLayer(.cloudSnow)],
    "fog": [IconLayer(.cloudFog)],
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
