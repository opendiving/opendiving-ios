import OpenDivingKit
import SwiftUI

/// The weather bar grown into ``MapWeatherCard`` over the dimmed map, presented over everything,
/// the top bar's other buttons included.
///
/// It opens on a copy of the bar where the bar is drawn, while the bar itself is hidden, and grows
/// the copy's glass into the card's; closing shrinks it back before the presentation ends, so the
/// bar is never seen to leave. Only the glass morphs: the bar's label and the card's lines fade, so
/// no line is laid out at a size it is never shown at.
struct MapWeatherExplainer: View {
  let content: MapWeatherContent
  /// Where the weather is, nil while it is looked up.
  let place: MapWeatherModel.Place?
  /// Where the bar is drawn, in the window's space.
  let barFrame: CGRect
  /// Looks up `place`, as the card opens.
  let lookUpPlace: () async -> Void
  /// Ends the presentation, once the card is back in the bar.
  let onClosed: () -> Void

  @State private var isOpen = false
  @Namespace private var morph
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { window in
      ZStack(alignment: .topLeading) {
        Color.black.opacity(isOpen ? 0.35 : 0)
          .contentShape(.rect)
          .onTapGesture(perform: close)
          .accessibilityLabel("Close")
          .accessibilityAddTraits(.isButton)
        // One glass, following the bar's copy and then the card, its corners easing between them.
        Self.glass(
          in: RoundedRectangle(cornerRadius: isOpen ? 26 : barFrame.height / 2, style: .continuous)
        )
        .matchedGeometryEffect(id: isOpen ? "card" : "bar", in: morph, isSource: false)
        .allowsHitTesting(false)
        if isOpen {
          card(in: window.size)
        } else {
          bar
        }
      }
    }
    .ignoresSafeArea()
    .task { await lookUpPlace() }
    .onAppear { withAnimation(morphing) { isOpen = true } }
    .accessibilityAction(.escape, close)
  }

  private var bar: some View {
    MapWeatherBarLabel(content: content)
      .mapWeatherBarLayout()
      .frame(width: barFrame.width, height: barFrame.height)
      .matchedGeometryEffect(id: "bar", in: morph)
      .padding(.leading, barFrame.minX)
      .padding(.top, barFrame.minY)
      .transition(.opacity.animation(.easeOut(duration: 0.12)))
      .accessibilityHidden(true)
  }

  private func card(in window: CGSize) -> some View {
    // Under the bar's top edge, and short of the home indicator.
    let height = window.height - barFrame.minY - 40
    return ViewThatFits(in: .vertical) {
      MapWeatherCard(content: content, place: place)
      ScrollView { MapWeatherCard(content: content, place: place) }
    }
    .frame(width: min(window.width - 32, 380))
    .frame(maxHeight: height, alignment: .top)
    .fixedSize(horizontal: false, vertical: true)
    .matchedGeometryEffect(id: "card", in: morph)
    .frame(width: window.width)
    .padding(.top, barFrame.minY)
    .transition(
      .asymmetric(
        insertion: .opacity.animation(.easeOut(duration: 0.2).delay(0.15)),
        removal: .opacity.animation(.easeIn(duration: 0.1)))
    )
    .accessibilityAddTraits(.isModal)
  }

  private var morphing: Animation {
    reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.15)
  }

  private func close() {
    withAnimation(morphing) {
      isOpen = false
    } completion: {
      onClosed()
    }
  }

  /// Shows or ends the presentation without its own slide, which would carry the bar away: the
  /// explainer animates what moves.
  static func present(_ change: () -> Void) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction, change)
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
  @Previewable @State var isExplaining = false
  @Previewable @State var barFrame = CGRect.zero
  NavigationStack {
    Color.teal.opacity(0.3)
      .ignoresSafeArea()
      .toolbar {
        ToolbarItem(placement: .principal) {
          MapWeatherBar(content: .sample) { MapWeatherExplainer.present { isExplaining = true } }
            .onGeometryChange(for: CGRect.self) {
              $0.frame(in: .global)
            } action: {
              barFrame = $0
            }
            .opacity(isExplaining ? 0 : 1)
        }
      }
  }
  .fullScreenCover(isPresented: $isExplaining) {
    MapWeatherExplainer(
      content: .sample,
      place: MapWeatherModel.Place(title: "Dahab, South Sinai, Egypt", credit: nil),
      barFrame: barFrame, lookUpPlace: {},
      onClosed: { MapWeatherExplainer.present { isExplaining = false } }
    )
    .presentationBackground(.clear)
  }
}
