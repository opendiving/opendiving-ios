import OpenDivingKit
import SwiftUI

/// The whole reading the weather bar stands for: the site's place, the reading in words with the
/// rest of the weather under it, the sea with its waves and tide drawn below that, and whose data
/// it is, which the provider's licence asks to be shown. Without a background: ``MapWeatherExplainer``
/// gives it the one it grows from the bar with.
struct MapWeatherCard: View {
  let content: MapWeatherContent
  /// The open site's place, else its name; nil while its panel reads it.
  let title: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // The placeholder only holds the line's height while the site's panel reads it.
      Text(title ?? "Place, Region, Country")
        .font(.subheadline.weight(.semibold))
        .redacted(reason: title == nil ? .placeholder : [])
      Text(content.summary)
        .font(.subheadline)
      if !content.details.isEmpty {
        DetailRows(details: content.details)
      }
      if !content.sea.isEmpty || content.waves != nil || content.tide != nil {
        Divider()
        if !content.sea.isEmpty {
          DetailRows(details: content.sea)
        }
        if let waves = content.waves {
          WaveProfileView(profile: waves)
        }
        if let tide = content.tide {
          TideCurveView(curve: tide)
        }
      }
      // Not underlined, as the credits over a map are: it is a link with text after it.
      AttributionLine(credits: [content.attribution], underline: false)
    }
    .padding()
  }
}

/// A label on the left and its value on the right, a line each, read by VoiceOver as one.
private struct DetailRows: View {
  let details: [MapWeatherContent.Detail]

  var body: some View {
    VStack(spacing: 2) {
      ForEach(details, id: \.label) { detail in
        HStack {
          Text(detail.label)
            .foregroundStyle(.secondary)
          Spacer()
          Text(detail.value)
            .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(detail.label)
        .accessibilityValue(detail.spokenValue)
      }
    }
    .font(.subheadline)
  }
}

extension MapWeatherContent {
  /// Dahab on a clear afternoon, with the sea, for previews.
  static let sample = MapWeatherContent(
    DiveConditionsCurrentRead(
      attribution: "[Weather data by Open-Meteo.com](https://open-meteo.com/)",
      at: DiveTimestamp(wireValue: "2026-11-10T17:00:00+02:00"),
      weather: ConditionsWeather(
        airTemperature: 24.4, relativeHumidity: 61.6, windSpeed: 5.9, windDirection: 45,
        windGusts: 8.3, cloudCover: 40, precipitation: 0.4, pressure: 1012.3, weatherCode: 2),
      sea: ConditionsSea(
        tideState: "rising",
        previousExtreme: ConditionsExtreme(
          kind: "low", at: DiveTimestamp(wireValue: "2026-11-10T13:10:00+02:00")!, height: -0.3),
        nextExtreme: ConditionsExtreme(
          kind: "high", at: DiveTimestamp(wireValue: "2026-11-10T19:20:00+02:00")!, height: 0.35),
        seaSurfaceTemperature: 25.5, waveHeight: 0.94, wavePeriod: 3.7, swellWaveHeight: 0.1)),
    units: .metric)!
}

#Preview {
  MapWeatherCard(content: .sample, title: "Dahab, South Sinai, Egypt")
    .frame(width: 340)
    .background(.regularMaterial, in: .rect(cornerRadius: 24))
    .padding()
    .background(Color.teal.opacity(0.3))
}
