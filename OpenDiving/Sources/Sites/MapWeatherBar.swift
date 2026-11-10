import OpenDivingKit
import SwiftUI

/// The weather at the centre of the Sites map, in its top bar: the sky, the air temperature and
/// the wind with an arrow along it. A tap grows it into ``MapWeatherCard``, the whole reading.
struct MapWeatherBar: View {
  let content: MapWeatherContent
  let onTap: () -> Void

  var body: some View {
    // Not a `Button`: the bar draws a button's label as its title or its icon alone, never both.
    MapWeatherBarLabel(content: content)
      .mapWeatherBarChrome()
      .onTapGesture(perform: onTap)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(content.accessibilityLabel)
      .accessibilityHint("Shows the whole reading and where it is from")
      .accessibilityAddTraits(.isButton)
      .accessibilityAction { onTap() }
  }
}

/// The bar's sky, temperature and wind, without its capsule: drawn by the bar, and by the copy of
/// it that grows into the card.
struct MapWeatherBarLabel: View {
  let content: MapWeatherContent

  var body: some View {
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
  }
}

extension View {
  /// The weather bar's capsule, as tall as the map's round buttons beside it.
  func mapWeatherBarChrome() -> some View {
    mapWeatherBarLayout()
      .contentShape(Capsule())
      .pickerControl(in: Capsule())
  }

  /// The bar's type and size without its glass.
  func mapWeatherBarLayout() -> some View {
    font(.subheadline)
      .monospacedDigit()
      .lineLimit(1)
      .fixedSize()
      .padding(.horizontal, 14)
      .frame(height: MapRoundButtonStyle.side)
  }
}

#Preview {
  NavigationStack {
    Color.teal.opacity(0.3)
      .ignoresSafeArea()
      .toolbar {
        ToolbarItem(placement: .principal) {
          MapWeatherBar(content: .sample, onTap: {})
        }
      }
  }
}
