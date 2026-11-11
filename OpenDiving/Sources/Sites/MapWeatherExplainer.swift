import OpenDivingKit
import SwiftUI

/// The weather bar grown into ``MapWeatherCard`` over the dimmed, softened map, presented over
/// everything, the top bar's other buttons included.
///
/// Everything is laid out from ``MapWeatherMorph``'s progress, so a finger can hold it anywhere
/// between the bar and the card as a tap's animation passes through it: the glass grows from where
/// the bar is drawn to the card's place, the bar's parts fly to the top of the card growing as they
/// go, the map dims, and the card's other lines ride along with that row, zoomed to fit inside the
/// glass, fading in as it nears the card's place. The bar is hidden for as long as its copy here
/// stands in for it.
struct MapWeatherExplainer: View {
  let content: MapWeatherContent
  /// The open site's place, else its name.
  let title: String?
  /// Where the bar is drawn, in the window's space.
  let barFrame: CGRect
  let morph: MapWeatherMorph

  /// Where the card stands open, in the window's space; nil until it is laid out.
  @State private var cardFrame: CGRect?
  @State private var barSlots: [MapWeatherPart: CGPoint] = [:]
  @State private var cardSlots: [MapWeatherPart: CGPoint] = [:]
  @ScaledMetric(relativeTo: .subheadline) private var barSize = MapWeatherBarLabel.size
  @ScaledMetric(relativeTo: .title2) private var cardSize = MapWeatherCard.size
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    GeometryReader { window in
      MapWeatherMorphScene(
        progress: morph.progress, content: content, barFrame: barFrame, cardFrame: cardFrame,
        barSlots: barSlots, cardSlots: cardSlots, barSize: barSize, cardSize: cardSize,
        dimming: dimming, close: morph.close, bar: bar, card: card(in: window.size))
    }
    .ignoresSafeArea()
    .onAppear {
      morph.animation =
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.15)
    }
    .accessibilityAction(.escape, morph.close)
  }

  /// The bar's copy, laid out where the bar is for its parts' places, and drawn by nothing.
  private var bar: some View {
    MapWeatherBarLabel(
      content: content,
      slots: MapWeatherSlots(place: .bar) { part, point in
        barSlots[part] = point
        if barSlots.count == parts.count { morph.coversBar = true }
      }
    )
    .mapWeatherBarLayout()
    .frame(width: barFrame.width, height: barFrame.height)
    .padding(.leading, barFrame.minX)
    .padding(.top, barFrame.minY)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private func card(in window: CGSize) -> some View {
    // From the bar's top edge to as far again and a little more from the bottom: centred there,
    // the card sits just above the screen's middle, where it reads as centred.
    let height = window.height - 2 * barFrame.minY - 40
    let slots = MapWeatherSlots(place: .card, space: Self.cardSpace) { part, point in
      if Self.moved(cardSlots[part], point) { cardSlots[part] = point }
    }
    return ViewThatFits(in: .vertical) {
      MapWeatherCard(content: content, title: title, slots: slots)
      ScrollView {
        MapWeatherCard(content: content, title: title, slots: slots)
      }
    }
    .frame(width: min(window.width - 32, 380))
    .frame(maxHeight: height, alignment: .top)
    .fixedSize(horizontal: false, vertical: true)
    // A sheet's grabber on the edge the card is pushed from, in its bottom margin.
    .overlay(alignment: .bottom) {
      Capsule()
        .fill(.tertiary)
        .frame(width: 36, height: 5)
        .padding(.bottom, 10)
        .accessibilityHidden(true)
    }
    .onGeometryChange(for: CGRect.self) {
      $0.frame(in: .named(Self.cardSpace))
    } action: { frame in
      guard Self.moved(cardFrame, frame) else { return }
      cardFrame = frame
      morph.distance = max(120, frame.midY - barFrame.midY)
    }
    // The whole card takes a touch, its blanks included: a push starting between a label and its
    // value moves it, and a tap there leaves it open rather than reaching the dim behind.
    .contentShape(.rect(cornerRadius: 26))
    .gesture(
      // On the window, since the card changes under the finger.
      DragGesture(minimumDistance: 12, coordinateSpace: .global)
        .onChanged { morph.push($0.translation.height) }
        .onEnded { morph.pushEnded(predicted: $0.predictedEndTranslation.height) }
    )
    .frame(width: window.width, height: height)
    .padding(.top, barFrame.minY)
    // The window's space as the card is laid out, which moving and zooming it leaves alone: its
    // place and its slots are where it comes to rest, not where it is passing.
    .coordinateSpace(.named(Self.cardSpace))
    .accessibilityAddTraits(.isModal)
  }

  nonisolated private static let cardSpace = "MapWeatherExplainer.card"

  /// Whether a measure of the card moved by more than rounding: drawn moved and zoomed, the card
  /// lands on the screen's pixels a fraction apart from where it rests, and taking that for a move
  /// would move it again, without end.
  private static func moved(_ old: CGPoint?, _ new: CGPoint) -> Bool {
    guard let old else { return true }
    return abs(new.x - old.x) >= 1 || abs(new.y - old.y) >= 1
  }

  private static func moved(_ old: CGRect?, _ new: CGRect) -> Bool {
    guard let old else { return true }
    return moved(old.origin, new.origin)
      || moved(CGPoint(x: old.maxX, y: old.maxY), CGPoint(x: new.maxX, y: new.maxY))
  }

  /// Darker in dark mode, where a light dim over dark tiles and a black panel barely shows.
  private var dimming: Double {
    colorScheme == .dark ? 0.6 : 0.35
  }

  private var parts: [MapWeatherPart] {
    MapWeatherPart.allCases.filter { $0.shows(content) }
  }
}

/// The presentation at one point of its progress, redrawn at each point an animation or a finger
/// passes through, rather than animated between two layouts: what eases in late, as the card's
/// lines do, then follows the progress whatever drives it.
private struct MapWeatherMorphScene<Bar: View, Card: View>: View, Animatable {
  var progress: CGFloat
  let content: MapWeatherContent
  let barFrame: CGRect
  let cardFrame: CGRect?
  let barSlots: [MapWeatherPart: CGPoint]
  let cardSlots: [MapWeatherPart: CGPoint]
  let barSize: CGFloat
  let cardSize: CGFloat
  let dimming: Double
  let close: () -> Void
  let bar: Bar
  let card: Card

  var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  var body: some View {
    let glass = Self.between(barFrame, cardFrame ?? barFrame, progress)
    let corner = Self.between(barFrame.height / 2, 26, progress)
    ZStack(alignment: .topLeading) {
      BackdropBlur(amount: 0.3)
        .opacity(progress)
        .overlay(Color.black.opacity(progress * dimming))
        .contentShape(.rect)
        .onTapGesture(perform: close)
        .accessibilityLabel("Close")
        .accessibilityAddTraits(.isButton)
      bar
      Self.glass(in: RoundedRectangle(cornerRadius: corner, style: .continuous))
        .frame(width: glass.width, height: glass.height)
        .position(x: glass.midX, y: glass.midY)
        .allowsHitTesting(false)
      let lines = lines(in: glass)
      card
        // Late enough that the parts flying in have cleared the place's name.
        .opacity(min(max((progress - 0.8) / 0.2, 0), 1))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .scaleEffect(lines.scale, anchor: .topLeading)
        .offset(lines.offset)
        .mask {
          RoundedRectangle(cornerRadius: corner, style: .continuous)
            .frame(width: glass.width, height: glass.height)
            .position(x: glass.midX, y: glass.midY)
        }
      ForEach(MapWeatherPart.allCases.filter { $0.shows(content) }, id: \.self) { part in
        if let from = barSlots[part] {
          let to = cardSlots[part] ?? from
          part.view(content, size: Self.between(barSize, cardSize, progress))
            .position(
              x: Self.between(from.x, to.x, progress), y: Self.between(from.y, to.y, progress)
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
      }
    }
  }

  /// How the card's lines are drawn at this point: zoomed about their top row and moved so that row
  /// rides where the bar's parts are flying, at the largest size that keeps every line inside the
  /// glass, so none is ever cut by its edge.
  private func lines(in glass: CGRect) -> (scale: CGFloat, offset: CGSize) {
    let row = MapWeatherPart.allCases.lazy.compactMap { part in
      barSlots[part].flatMap { from in cardSlots[part].map { (from: from, to: $0) } }
    }.first
    guard let cardFrame, let row else {
      let rest = cardFrame ?? glass
      return (1, CGSize(width: glass.midX - rest.midX, height: glass.midY - rest.midY))
    }
    let rest = CGPoint(x: cardFrame.midX, y: row.to.y)
    let now = CGPoint(x: glass.midX, y: Self.between(row.from.y, row.to.y, progress))
    let fit = min(
      1, glass.width / cardFrame.width, (now.y - glass.minY) / (rest.y - cardFrame.minY),
      (glass.maxY - now.y) / (cardFrame.maxY - rest.y))
    let scale = max(fit, 0.01)
    return (scale, CGSize(width: now.x - scale * rest.x, height: now.y - scale * rest.y))
  }

  private static func between(_ from: CGFloat, _ to: CGFloat, _ progress: CGFloat) -> CGFloat {
    from + (to - from) * progress
  }

  private static func between(_ from: CGRect, _ to: CGRect, _ progress: CGFloat) -> CGRect {
    CGRect(
      x: between(from.minX, to.minX, progress), y: between(from.minY, to.minY, progress),
      width: between(from.width, to.width, progress),
      height: between(from.height, to.height, progress))
  }

  /// The toolbar's glass, or its material before iOS 26: what the bar is drawn on, so the copy
  /// matches it and the card is the same glass grown.
  @ViewBuilder private static func glass(in shape: some Shape) -> some View {
    if #available(iOS 26, *) {
      Color.clear.glassEffect(.regular, in: shape)
    } else {
      shape.fill(.regularMaterial)
    }
  }
}

#Preview {
  @Previewable @State var morph = MapWeatherMorph()
  @Previewable @State var barFrame = CGRect.zero
  NavigationStack {
    Color.teal.opacity(0.3)
      .ignoresSafeArea()
      .toolbar {
        ToolbarItem(placement: .principal) {
          MapWeatherBar(
            content: .sample, onTap: morph.open, onPull: morph.pull,
            onPullEnded: morph.pullEnded
          )
          .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .global)
          } action: {
            barFrame = $0
          }
          .opacity(morph.coversBar ? 0 : 1)
        }
      }
  }
  .fullScreenCover(isPresented: $morph.isPresented) {
    MapWeatherExplainer(
      content: .sample, title: "Dahab, South Sinai, Egypt", barFrame: barFrame, morph: morph
    )
    .presentationBackground(.clear)
  }
}
