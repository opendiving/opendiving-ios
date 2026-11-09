import OpenDivingKit
import SwiftUI

/// The weather at the centre of the Sites map, in its top bar: the sky, the air temperature and
/// the wind with an arrow along it. A tap shows what it is and whose data it is, which the
/// provider's licence asks to be shown.
struct MapWeatherBar: View {
  let content: MapWeatherContent
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
    .font(.subheadline)
    .monospacedDigit()
    .lineLimit(1)
    .fixedSize()
    .padding(.horizontal, 14)
    .frame(height: MapRoundButtonStyle.side)
    .contentShape(Capsule())
    .pickerControl(in: Capsule())
    .onTapGesture { isExplained = true }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(content.accessibilityLabel)
    .accessibilityHint("Shows where the weather is from")
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { isExplained = true }
    .popover(isPresented: $isExplained) {
      VStack(alignment: .leading, spacing: 8) {
        Text("At the centre of the map, now")
          .font(.subheadline.weight(.semibold))
        Text(content.accessibilityLabel)
          .font(.subheadline)
        AttributionLine(credits: [content.attribution])
      }
      .padding()
      .frame(idealWidth: 280)
      .presentationCompactAdaptation(.popover)
    }
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
            MapWeatherBar(content: content)
          }
        }
      }
  }
}
