import CoreLocation
import OpenDivingKit
import SwiftUI

/// The site finder the Sites tab is and the dive form's site picker opens: the map full screen
/// under a panel that holds the search and the list, *Your sites* and *Use my location* floating
/// over the map's corner above the panel, and a spinner under the top bar while the list is asked
/// for again. With no map on the instance the panel stands alone, at its tallest. What a site
/// does when chosen, and the top bar's buttons, are the host's; the bar draws no background over
/// the map.
struct SiteFinderView<Bar: ToolbarContent>: View {
  let model: SiteFinderModel
  let map: MapStyleModel
  let units: UnitSystem
  /// What choosing a point on the map does, `Open site` or `Add to dive`.
  let pointAction: String
  /// Under *Your sites*, the Sites tab's cards with their figures rather than plain rows.
  var showsCards = false
  /// A site chosen from the list or the map.
  let onSite: (DiveSiteLookupItem) -> Void
  /// A long press on the map, where a site is added.
  var onLongPress: ((DeviceLocation) -> Void)?
  /// What the dive form lists while the search cannot reach the server: the phone's lookup rows.
  var offlineRows: ((String) -> [FormPickerRow])?
  var onOfflineRow: (FormPickerRow) -> Void = { _ in }
  @ToolbarContentBuilder let bar: () -> Bar

  @State private var detent = SiteFinderPanel.Detent.half
  /// How far a drag on the handle, the search or the list from its top has pulled the panel up,
  /// and whether it is on the move.
  @State private var drag = SiteFinderPanelDrag()
  @FocusState private var typing: Bool
  /// Where the panel stood when the search took focus, which its close button returns it to.
  @State private var detentBeforeTyping: SiteFinderPanel.Detent?

  var body: some View {
    @Bindable var model = model
    GeometryReader { geometry in
      let panel = SiteFinderPanel(available: geometry.size.height)
      ZStack(alignment: .top) {
        if let style = map.shown {
          mapArea(style, geometry: geometry, panel: panel)
        } else {
          Color(.systemGroupedBackground).ignoresSafeArea()
        }
        // Placed from the top: with the keyboard up the bottom edge moves, though it is ignored.
        panelView(panel, below: geometry.safeAreaInsets.bottom)
          .modifier(
            RidesPanel(
              drag: drag, panel: panel, detent: map.hasMap ? detent : .full,
              foot: geometry.size.height))
      }
    }
    // The list is scrolled to reach what the keyboard covers, which dismisses it.
    .ignoresSafeArea(.keyboard)
    .toolbar {
      if !map.hasMap {
        ToolbarItemGroup(placement: .topBarTrailing) {
          yoursButton.mapBarButton(isOn: model.yours)
          locateButton.mapBarButton()
        }
        ToolbarIslandGap()
      }
      bar()
    }
    .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
    .navigationBarTitleDisplayMode(.inline)
    .showsMapStyle(map)
    .onChange(of: map.hasMap, initial: true) { _, hasMap in model.hasMap = hasMap }
    .onChange(of: typing) { _, typing in
      if typing {
        detentBeforeTyping = detent
        move(to: .full)
      } else {
        detentBeforeTyping = nil
      }
    }
    .onChange(of: detent) { _, detent in
      if detent != .full { typing = false }
    }
    .task { await model.open() }
    .task { await model.points.load() }
    .task { await model.followRoute() }
    .task(id: model.text) {
      try? await Task.sleep(for: .milliseconds(300))
      guard !Task.isCancelled else { return }
      await model.typed()
    }
    .sheet(item: $model.selected) { point in
      SiteFinderPointSheet(point: point, action: pointAction) {
        model.selected = nil
        onSite(point.lookupItem)
      }
      .presentationDetents([.height(180)])
      .presentationDragIndicator(.visible)
    }
  }

  // MARK: - The map

  /// The detent the map makes room for: at its tallest the panel hides the map, which keeps the
  /// half it had.
  private var mapDetent: SiteFinderPanel.Detent {
    detent == .full ? .half : detent
  }

  private func mapArea(
    _ style: MapStyleModel.Shown, geometry: GeometryProxy, panel: SiteFinderPanel
  ) -> some View {
    let covered = UIEdgeInsets(
      top: geometry.safeAreaInsets.top, left: 0,
      bottom: geometry.safeAreaInsets.bottom + panel.height(mapDetent), right: 0)
    let shown = (
      width: Double(geometry.size.width),
      height: max(0, geometry.size.height - panel.height(mapDetent))
    )
    return ZStack(alignment: .bottom) {
      SiteFinderMap(
        styleJSON: style.styleJSON, camera: model.camera, covered: covered,
        commons: model.yours ? nil : model.points.commons, yours: model.points.yours,
        selected: model.selected,
        onCameraChange: { camera, byGesture in model.mapMoved(to: camera, byGesture: byGesture) },
        onPoint: { model.select($0) },
        onLongPress: onLongPress.map { add in
          { add(DeviceLocation(latitude: $0.latitude, longitude: $0.longitude)) }
        }
      )
      .accessibilityLabel("Map of dive sites")
      .ignoresSafeArea()
      .onChange(of: [shown.width, shown.height], initial: true) {
        model.viewport = shown
      }
      statusBarBlur
      HStack(alignment: .bottom) {
        MapCredit(credit: style.credit)
        Spacer()
        VStack(spacing: 12) {
          yoursButton.mapRoundButton(isOn: model.yours)
          locateButton.mapRoundButton()
        }
      }
      .padding(.horizontal, 12)
      .padding(.bottom, 12)
      .modifier(RidesPanel(drag: drag, panel: panel, detent: detent, fades: true))
    }
  }

  private var locateButton: some View {
    Button {
      Task { await model.useMyLocation() }
    } label: {
      Group {
        if model.isLocating {
          BubbleSpinner()
        } else {
          Image(Icon.locateFixed)
        }
      }
      .frame(width: MapRoundButtonStyle.glassLabelSide, height: MapRoundButtonStyle.glassLabelSide)
    }
    .accessibilityLabel(model.isLocating ? SiteFinderText.locating : SiteFinderText.useMyLocation)
    .disabled(model.isLocating)
  }

  private var yoursButton: some View {
    Button {
      Task { await model.setYours(!model.yours) }
    } label: {
      Image(Icon.bookmark)
        .frame(
          width: MapRoundButtonStyle.glassLabelSide, height: MapRoundButtonStyle.glassLabelSide)
    }
    .accessibilityLabel(SiteFinderText.yoursLabel)
    .accessibilityAddTraits(model.yours ? .isSelected : [])
  }

  /// A light blur fading down over the status bar alone, which keeps it readable over whatever
  /// the map draws there. The geometry's top inset also holds the navigation bar, under which the
  /// map stays sharp.
  private var statusBarBlur: some View {
    let scene = UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first
    let height = scene?.statusBarManager?.statusBarFrame.height ?? 0
    return ProgressiveBlur(edge: .top, radius: 1, hold: 0.5)
      .frame(height: height + 6)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .ignoresSafeArea()
  }

  // MARK: - The panel

  /// `below` is the safe area under the panel, the tab bar's or the home indicator's, which its
  /// fill runs on through.
  private func panelView(_ panel: SiteFinderPanel, below: Double) -> some View {
    let shape = UnevenRoundedRectangle(
      topLeadingRadius: Self.panelRadius, topTrailingRadius: Self.panelRadius)
    return VStack(spacing: 0) {
      VStack(spacing: 0) {
        if map.hasMap { handle(panel) }
        HStack(spacing: 8) {
          searchField
          if typing { closeSearchButton }
        }
        .padding(.horizontal, 16)
        .padding(.top, map.hasMap ? 0 : 16)
        .padding(.bottom, 12)
      }
      .contentShape(Rectangle())
      .gesture(
        PanelPan(
          isEnabled: map.hasMap, onChanged: { drag.follow(-$0) },
          onEnded: { letGo(panel, velocity: -$0) }))
      if let failure = model.locationFailure {
        FieldMessage(SiteFinderText.locationFailure(failure))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 16)
          .padding(.bottom, 8)
      }
      list(panel)
    }
    .frame(
      height: map.hasMap && !drag.isMoving ? panel.height(detent) : panel.height(.full),
      alignment: .top
    )
    .frame(maxWidth: .infinity)
    .clipShape(shape)
    .background {
      shape
        .fill(Color(.systemGroupedBackground))
        .shadow(color: .black.opacity(0.15), radius: 8, y: -2)
        // Runs on under a panel that lands a little short of its height, or a spring that
        // carries its foot above the screen's.
        .padding(.bottom, -below - 40)
    }
  }

  private static var panelRadius: Double {
    if #available(iOS 26, *) { 26 } else { 12 }
  }

  /// Drags the panel, and steps it for VoiceOver and a tap.
  private func handle(_ panel: SiteFinderPanel) -> some View {
    Capsule()
      .fill(.tertiary)
      .frame(width: 36, height: 5)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
      .onTapGesture {
        move(to: detent == .half ? .full : .half)
      }
      .accessibilityElement()
      .accessibilityLabel("List of dive sites")
      .accessibilityValue(Self.spoken(detent))
      .accessibilityAdjustableAction { direction in
        let all = SiteFinderPanel.Detent.allCases
        guard let at = all.firstIndex(of: detent) else { return }
        switch direction {
        case .increment where at + 1 < all.count: detent = all[at + 1]
        case .decrement where at > 0: detent = all[at - 1]
        default: break
        }
      }
  }

  private static func spoken(_ detent: SiteFinderPanel.Detent) -> String {
    switch detent {
    case .collapsed: "Collapsed"
    case .half: "Half screen"
    case .full: "Full screen"
    }
  }

  /// Settles the panel at the detent the drag was heading for, the spring starting at the
  /// finger's speed rather than from rest. `velocity` is upward positive.
  private func letGo(_ panel: SiteFinderPanel, velocity: Double) {
    let release = panel.release(from: detent, dragged: drag.dragged, velocity: velocity)
    move(
      to: release.detent,
      on: .interpolatingSpring(.snappy, initialVelocity: release.velocity))
  }

  /// Moves the panel to `target`, laid out at its tallest until it lands rather than resized on
  /// every frame of the way.
  private func move(to target: SiteFinderPanel.Detent, on animation: Animation = .snappy) {
    let number = drag.begin()
    withAnimation(animation) {
      detent = target
      drag.letGo()
    } completion: {
      drag.end(number)
    }
  }

  private var searchField: some View {
    @Bindable var model = model
    return HStack(spacing: 8) {
      Image(Icon.search)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      TextField(SiteFinderText.searchPrompt, text: $model.text)
        .autocorrectionDisabled()
        .submitLabel(.search)
        .focused($typing)
      if !model.text.isEmpty {
        Button("Clear search", systemImage: "xmark.circle.fill") { model.text = "" }
          .labelStyle(.iconOnly)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 14)
    .frame(height: 44)
    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
  }

  private var closeSearchButton: some View {
    Button {
      let back = detentBeforeTyping ?? .half
      typing = false
      move(to: back)
    } label: {
      Image(systemName: "xmark")
        .frame(width: 44, height: 44)
        .contentShape(Circle())
    }
    .accessibilityLabel("Close search")
    .buttonStyle(.plain)
    .background(Color(.secondarySystemGroupedBackground), in: Circle())
  }

  // MARK: - The list

  /// Over a map a drag down from the list's top moves the panel, so only the panel with no map,
  /// which stands still, pulls to refresh.
  @ViewBuilder private func list(_ panel: SiteFinderPanel) -> some View {
    if map.hasMap {
      scrolledList(panel)
    } else {
      scrolledList(panel).bubbleRefreshable { await model.list?.refresh() }
    }
  }

  private func scrolledList(_ panel: SiteFinderPanel) -> some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        content
      }
      .padding(.horizontal)
      .padding(.bottom)
      .background {
        if map.hasMap {
          PanelDragFromScrollTop(
            onChanged: { drag.follow(-$0) }, onEnded: { letGo(panel, velocity: -$0) })
        }
      }
    }
    .scrollDismissesKeyboard(.immediately)
  }

  @ViewBuilder private var content: some View {
    if model.isOpening && model.list == nil {
      BubbleSpinner().frame(maxWidth: .infinity).padding(.top, 24)
    } else if let list = model.list {
      switch list.phase {
      case .idle, .loading:
        BubbleSpinner().frame(maxWidth: .infinity).padding(.top, 24)
      case .failed(let error):
        if let offlineRows, error.isUnreachable {
          offline(offlineRows(model.text), error: error)
        } else {
          note(SiteFinderText.failure(error))
        }
      case .loaded where model.rows.isEmpty:
        note(SiteFinderText.empty(typed: model.isTyped, yours: model.yours))
      case .loaded:
        if let lastUpdated = model.lastUpdated {
          LastUpdatedLine(date: lastUpdated)
        }
        ForEach(model.rows) { row in
          rowView(row)
            .onAppear { Task { await model.loadMore(after: row) } }
        }
        let credits = SiteFinderRowContent.placeCredits(model.rows)
        if !credits.isEmpty {
          AttributionLine(credits: credits)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        LoadMoreFooter(list: list)
      }
    }
  }

  @ViewBuilder private func rowView(_ row: DiveSiteSearchRow) -> some View {
    switch row {
    case .site(let item):
      Button {
        onSite(item.site)
      } label: {
        if showsCards && model.yours {
          VStack(alignment: .leading, spacing: 4) {
            RecordCardView(content: DiveSiteSummary.card(item, units: units), icon: .tabDiveSite)
            if let attribution = item.attribution {
              AttributionLine(credits: [attribution])
            }
          }
        } else {
          SiteFinderRow(content: SiteFinderRowContent(row, units: units))
        }
      }
      .buttonStyle(.plain)
    case .place(let item):
      Button {
        typing = false
        move(to: .half)
        Task { await model.pick(item) }
      } label: {
        SiteFinderRow(content: SiteFinderRowContent(row, units: units))
      }
      .buttonStyle(.plain)
    }
  }

  /// The dive form's picker with no route: the rows the phone holds, as the picker listed them.
  @ViewBuilder private func offline(_ rows: [FormPickerRow], error: APIError) -> some View {
    note(SiteFinderText.failure(error))
    ForEach(rows) { row in
      Button {
        onOfflineRow(row)
      } label: {
        PickerRowLabel(row: row, showsCredit: true)
          .padding(12)
          .background(
            Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
      }
      .buttonStyle(.plain)
    }
  }

  private func note(_ text: String) -> some View {
    Text(text)
      .font(.footnote)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Moves what it modifies with the panel's top edge, which is `foot` less the panel's height
/// from where it sits: the panel is placed from the top of the finder, the controls riding on
/// it from the bottom. Only this reads how far the panel is dragged, so a drag draws nothing else
/// again.
private struct RidesPanel: ViewModifier {
  let drag: SiteFinderPanelDrag
  let panel: SiteFinderPanel
  let detent: SiteFinderPanel.Detent
  var foot = 0.0
  /// Fades out above the half the panel opens to, as the controls over the map do.
  var fades = false

  func body(content: Content) -> some View {
    let height = panel.height(detent, dragged: drag.dragged)
    let opacity = fades ? panel.controlsOpacity(shown: height) : 1
    content
      .offset(y: foot - height)
      .opacity(opacity)
      .allowsHitTesting(opacity > 0)
      .accessibilityHidden(opacity == 0)
  }
}

/// One row of the finder's list: a site with its distance, mark and credit, or a place with how
/// many sites are near it.
private struct SiteFinderRow: View {
  let content: SiteFinderRowContent

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(content.isPlace ? Icon.mapPin : Icon.diveSite)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      // The credit sits outside the distance's row, so it runs on under the distance rather
      // than wrapping in the narrower column beside it.
      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .top, spacing: 12) {
          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
              Text(content.title).foregroundStyle(Color.primary)
              if let mark = content.mark {
                BadgeView(mark.label, style: .outline) { DiveSiteMarkIcon(mark: mark) }
                  .accessibilityElement(children: .ignore)
                  .accessibilityLabel(mark.accessibilityLabel)
              }
            }
            if let subtitle = content.subtitle {
              Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            if let nearby = content.nearby {
              Text(nearby).font(.footnote).foregroundStyle(.secondary)
            }
          }
          Spacer(minLength: 0)
          if let distance = content.distance {
            Text(distance).font(.subheadline).foregroundStyle(.secondary)
          }
        }
        if let credit = content.credit {
          AttributionLine(credits: [credit])
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    .contentShape(Rectangle())
  }
}

/// What a touched point opens: the site, its mark and credit, and what choosing it does.
private struct SiteFinderPointSheet: View {
  let point: SiteFinderPoint
  let action: String
  let onChoose: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      PickerRowLabel(row: FormPickerRow(point.lookupItem), showsCredit: true)
      Button(action, action: onChoose)
        .buttonStyle(.borderedProminent)
        .tint(Color.brandTeal)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(24)
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  NavigationStack {
    SiteFinderView(
      model: SiteFinderModel(
        session: session, locator: CoreLocationProvider(),
        today: CalendarDate(year: 2026, month: 11, day: 8)!),
      map: MapStyleModel(session: session), units: .metric, pointAction: "Open site",
      onSite: { _ in },
      bar: { ToolbarItem(placement: .topBarTrailing) { Button("Add", systemImage: "plus") {} } })
  }
  .environment(session)
}
