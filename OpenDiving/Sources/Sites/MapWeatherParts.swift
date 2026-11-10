import OpenDivingKit
import SwiftUI

/// The sky and the air temperature, drawn at `size` points: small in the weather bar, large at the
/// top of its card, and every size between as one flies to the other. The icon is sized from the
/// text rather than by the font, which a loaded symbol does not follow, so the two keep their
/// proportions at any size.
struct MapWeatherSky: View {
  let content: MapWeatherContent
  let size: CGFloat

  var body: some View {
    HStack(spacing: size * 0.4) {
      if let icon = content.icon {
        Image(loaded: icon)
          .resizable()
          .scaledToFit()
          .frame(width: size * 1.2, height: size * 1.2)
          .foregroundStyle(content.iconTone.map(Color.weather) ?? .primary)
      }
      if let temperature = content.temperature {
        Text(temperature)
      }
    }
    .font(.system(size: size))
    .monospacedDigit()
    .lineLimit(1)
    .fixedSize()
  }

  static func shows(_ content: MapWeatherContent) -> Bool {
    content.icon != nil || content.temperature != nil
  }
}

/// The wind's speed with an arrow along it, drawn at `size` points as ``MapWeatherSky`` is.
struct MapWeatherWind: View {
  let content: MapWeatherContent
  let size: CGFloat

  var body: some View {
    // Wider than the label's: turned, the arrow's corners reach past its frame.
    HStack(spacing: size / 3) {
      if let heading = content.windHeading {
        Image(loaded: .navigation2)
          .resizable()
          .scaledToFit()
          .frame(width: size * 0.85, height: size * 0.85)
          .rotationEffect(.degrees(heading))
          .foregroundStyle(Color.brandCoral)
      }
      if let windSpeed = content.windSpeed {
        Text(windSpeed)
      }
    }
    .font(.system(size: size))
    .monospacedDigit()
    .lineLimit(1)
    .fixedSize()
  }

  static func shows(_ content: MapWeatherContent) -> Bool {
    content.windSpeed != nil
  }
}

/// The sea's surface temperature beside a wave, drawn at `size` points as ``MapWeatherSky`` is.
struct MapWeatherSea: View {
  let content: MapWeatherContent
  let size: CGFloat

  var body: some View {
    HStack(spacing: size * 0.4) {
      Image(loaded: .waves)
        .resizable()
        .scaledToFit()
        .frame(width: size * 1.2, height: size * 1.2)
        .foregroundStyle(Color.weather(.water))
      if let sea = content.seaTemperature {
        Text(sea.value)
      }
    }
    .font(.system(size: size))
    .monospacedDigit()
    .lineLimit(1)
    .fixedSize()
  }

  static func shows(_ content: MapWeatherContent) -> Bool {
    content.seaTemperature != nil
  }
}

extension Color {
  /// The colour a weather icon's tone is drawn in: the sun's yellow, or the teal of water, lighter
  /// in the dark, where #008080 is too dim on dark glass.
  static func weather(_ tone: MapWeatherContent.Tone) -> Color {
    switch tone {
    case .sun: .sun
    case .water: .accentText
    }
  }
}

/// The parts of the bar, each flying to the top of its card.
enum MapWeatherPart: String, CaseIterable {
  case sky, wind, sea

  func shows(_ content: MapWeatherContent) -> Bool {
    switch self {
    case .sky: MapWeatherSky.shows(content)
    case .wind: MapWeatherWind.shows(content)
    case .sea: MapWeatherSea.shows(content)
    }
  }

  /// The part drawn at `size` points.
  @ViewBuilder func view(_ content: MapWeatherContent, size: CGFloat) -> some View {
    switch self {
    case .sky: MapWeatherSky(content: content, size: size)
    case .wind: MapWeatherWind(content: content, size: size)
    case .sea: MapWeatherSea(content: content, size: size)
    }
  }
}

/// Where the bar's parts sit, in the bar's copy or the card, for the parts flying between them to
/// follow: the parts at a slot are laid out and left undrawn.
struct MapWeatherSlots {
  enum Place: String {
    case bar, card
  }

  let namespace: Namespace.ID
  let place: Place

  static func id(_ part: MapWeatherPart, _ place: Place) -> String {
    "\(part.rawValue)-\(place.rawValue)"
  }
}

extension View {
  /// A part held at its slot: undrawn, its middle the one a flying part follows.
  @ViewBuilder func mapWeatherSlot(_ part: MapWeatherPart, _ slots: MapWeatherSlots?) -> some View {
    if let slots {
      opacity(0)
        .matchedGeometryEffect(
          id: MapWeatherSlots.id(part, slots.place), in: slots.namespace, properties: .position)
    } else {
      self
    }
  }
}

/// A part redrawn at each size an animation passes through, rather than scaled, so its text stays
/// sharp while it grows.
struct MapWeatherSized<Part: View>: View, Animatable {
  var size: CGFloat
  let part: (CGFloat) -> Part

  init(size: CGFloat, @ViewBuilder part: @escaping (CGFloat) -> Part) {
    self.size = size
    self.part = part
  }

  var animatableData: CGFloat {
    get { size }
    set { size = newValue }
  }

  var body: some View {
    part(size)
  }
}

#Preview {
  VStack(alignment: .leading, spacing: 16) {
    HStack {
      MapWeatherSky(content: .sample, size: 15)
      MapWeatherWind(content: .sample, size: 15)
    }
    HStack {
      MapWeatherSky(content: .sample, size: 26)
      MapWeatherWind(content: .sample, size: 26)
    }
  }
  .padding()
}
