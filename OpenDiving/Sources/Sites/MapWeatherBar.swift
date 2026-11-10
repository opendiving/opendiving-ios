import OpenDivingKit
import SwiftUI

/// The weather at the centre of the Sites map, in its top bar: the sky, the air temperature and
/// the wind with an arrow along it. A tap shows where it is, the reading in words and whose data
/// it is, which the providers' licences ask to be shown.
struct MapWeatherBar: View {
  let content: MapWeatherContent
  /// Where the weather is, nil while it is looked up.
  let place: MapWeatherModel.Place?
  /// Looks up `place`, when the tap opens it.
  let lookUpPlace: () async -> Void
  @State private var isExplained = false

  var body: some View {
    // Not a `Button`: the bar draws a button's label as its title or its icon alone, never both.
    HStack(spacing: 6) {
      if let icon = content.icon {
        Image(loaded: icon)
      }
      if let temperature = content.temperature {
        Text(temperature)
      }
      if let windSpeed = content.windSpeed {
        // Wider than the label's: turned, the arrow's corners reach past its frame.
        HStack(spacing: 5) {
          if let heading = content.windHeading {
            Image(loaded: .navigation2)
              .imageScale(.small)
              .rotationEffect(.degrees(heading))
          }
          Text(windSpeed)
        }
        .padding(.leading, 4)
      }
    }
    .mapWeatherBarChrome()
    .onTapGesture { isExplained = true }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(content.accessibilityLabel)
    .accessibilityHint("Shows where the weather is from")
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { isExplained = true }
    .popover(isPresented: $isExplained) {
      VStack(alignment: .leading, spacing: 8) {
        // The placeholder only holds the line's height while the name is looked up.
        Text(place?.title ?? "Place, Region, Country")
          .font(.subheadline.weight(.semibold))
          .redacted(reason: place == nil ? .placeholder : [])
        Text(content.summary)
          .font(.subheadline)
        // A credit a line, so neither wraps; not underlined, as the credits over a map are, since
        // one credit is a single link and the other two with text between.
        VStack(alignment: .leading, spacing: 2) {
          AttributionLine(credits: [content.attribution], underline: false)
          if let credit = place?.credit {
            AttributionLine(credits: [credit], underline: false)
          }
        }
      }
      .task { await lookUpPlace() }
      .padding()
      // Wide enough for the provider's credit on one line.
      .frame(idealWidth: 320)
      .presentationCompactAdaptation(.popover)
    }
  }
}

extension View {
  /// The weather bar's capsule, as tall as the map's round buttons beside it.
  func mapWeatherBarChrome() -> some View {
    font(.subheadline)
      .monospacedDigit()
      .lineLimit(1)
      .fixedSize()
      .padding(.horizontal, 14)
      .frame(height: MapRoundButtonStyle.side)
      .contentShape(Capsule())
      .pickerControl(in: Capsule())
  }
}

#Preview {
  NavigationStack {
    Color.teal.opacity(0.3)
      .ignoresSafeArea()
      .toolbar {
        ToolbarItem(placement: .principal) {
          if let content = MapWeatherContent(
            DiveConditionsCurrentRead(
              attribution: "[Weather data by Open-Meteo.com](https://open-meteo.com/)",
              weather: ConditionsWeather(
                airTemperature: 24.4, windSpeed: 5.9, windDirection: 45, weatherCode: 2)),
            units: .metric)
          {
            MapWeatherBar(
              content: content,
              place: MapWeatherModel.Place(
                title: "Dahab, South Sinai, Egypt", credit: "[OSM](https://osm.org)"),
              lookUpPlace: {})
          }
        }
      }
  }
}
