import CoreLocation
import OpenDivingKit
import SwiftUI

/// The site finder the sites map is and the dive form's site picker opens: the map full screen
/// under a panel that holds the search and the list, an island at its lowest, *Your sites* and
/// *Use my location* floating over the map's corner above the panel, and a spinner under the top
/// bar while the list is asked for again. With no map on the instance the panel stands alone, at
/// its tallest. On the sites map a site opened from its row or its point takes the panel's search
/// and list, its pin larger at the middle of the map, which then only zooms about it, and the
/// others faded; on the dive form a touched point is named under a sheet. What a row does when chosen, what an opened site shows,
/// and the top bar's buttons, are the host's; the bar draws no background over the map.
struct SiteFinderView<Site: View, SiteAction: View, Bar: ToolbarContent>: View {
  let model: SiteFinderModel
  let map: MapStyleModel
  let units: UnitSystem
  /// What choosing a row or a touched point's sheet does on the dive form; the sites map opens
  /// either in the panel.
  var onSite: (DiveSiteLookupItem) -> Void = { _ in }
  /// A long press on the map, where a site is added.
  var onLongPress: ((DeviceLocation) -> Void)?
  /// What the dive form lists while the search cannot reach the server: the phone's lookup rows.
  var offlineRows: ((String) -> [FormPickerRow])?
  var onOfflineRow: (FormPickerRow) -> Void = { _ in }
  /// What the panel shows of the site the sites map opened, padded as it needs: the panel's width
  /// is its to fill.
  @ViewBuilder let site: (SiteFinderModel.OpenedSite) -> Site
  /// What stands under the opened site's close button: the way to edit it.
  @ViewBuilder let siteAction: (SiteFinderModel.OpenedSite) -> SiteAction
  @ToolbarContentBuilder let bar: () -> Bar

  /// Where the panel rests, and how a drag on the handle, the search or the list from its top or
  /// the spring after it is moving it.
  @State private var drag = SiteFinderPanelDrag()
  @FocusState private var typing: Bool

  var body: some View {
    @Bindable var model = model
    GeometryReader { geometry in
      let panel = SiteFinderPanel(available: geometry.size.height)
      ZStack(alignment: .top) {
        if let style = map.shown {
          mapArea(style, geometry: geometry, panel: panel)
        } else {
          Color.panelFill.ignoresSafeArea()
        }
        // Placed from the top: with the keyboard up the bottom edge moves, though it is ignored.
        panelView(panel, below: geometry.safeAreaInsets.bottom)
          .modifier(
            RidesPanel(
              drag: drag, panel: panel, pinned: map.hasMap ? nil : .full,
              foot: geometry.size.height, below: geometry.safeAreaInsets.bottom, hug: hug))
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
    .onChange(of: model.opened?.uuid) { old, new in
      guard map.hasMap, let detent = drag.detent(openingSite: new, after: old) else { return }
      move(to: detent)
    }
    .onChange(of: typing) { _, typing in
      if typing { move(to: .full) }
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
      SiteFinderPointSheet(point: point) {
        model.selected = nil
        onSite(point.lookupItem)
      }
      .presentationDetents([.height(180)])
      .presentationDragIndicator(.visible)
    }
  }

  /// How far the island closes in on what it holds: the search box alone has no panel around it,
  /// where an opened site keeps the panel's room about its name and close button.
  private var hug: Double { model.opened == nil ? PanelIsland.searchHug : 0 }

  // MARK: - The map

  /// The detent the map makes room for: where the panel is heading, so that a site opened as it
  /// moves glides once, straight to where it will show. At its tallest the panel hides the map,
  /// which keeps the half it had.
  private var mapDetent: SiteFinderPanel.Detent {
    drag.target == .full ? .half : drag.target
  }

  private func mapArea(
    _ style: MapStyleModel.Shown, geometry: GeometryProxy, panel: SiteFinderPanel
  ) -> some View {
    let below = geometry.safeAreaInsets.bottom
    let resting = panel.height(mapDetent)
    // How far the panel's top, or the island's, stands above the home indicator's inset.
    let share = panel.islandShare(shown: resting)
    let rise = resting - PanelIsland.drop(below: below, share: share, hug: hug) - hug * share
    let covered = UIEdgeInsets(
      top: geometry.safeAreaInsets.top, left: 0, bottom: below + rise, right: 0)
    let shown = (
      width: Double(geometry.size.width),
      height: max(0, geometry.size.height - rise)
    )
    return ZStack(alignment: .bottom) {
      SiteFinderMap(
        styleJSON: style.styleJSON, camera: model.camera, glides: model.glides, covered: covered,
        commons: model.yours ? nil : model.points.commons, yours: model.points.yours,
        selected: model.highlighted, holdsMiddle: model.holdsOpenedSite,
        onCameraChange: { camera, byGesture in model.mapMoved(to: camera, byGesture: byGesture) },
        onPoint: { model.select($0) },
        onMapTap: { model.closeSite() },
        onLongPress: onLongPress.map { add in
          { add(DeviceLocation(latitude: $0.latitude, longitude: $0.longitude)) }
        }
      )
      .accessibilityLabel("Map of dive sites")
      .ignoresSafeArea()
      .onChange(of: [shown.width, shown.height], initial: true) {
        model.viewport = shown
      }
      TopBarBlur()
      HStack(alignment: .bottom) {
        MapCredit(credit: style.credit)
        Spacer()
        VStack(spacing: 12) {
          yoursButton.mapRoundButton(isOn: model.yours)
          locateButton.mapRoundButton()
        }
      }
      // On the panel's content edge, where the islands stand too.
      .padding(.horizontal, PanelIsland.margin)
      .padding(.bottom, 12)
      .modifier(
        RidesPanel(
          drag: drag, panel: panel, below: geometry.safeAreaInsets.bottom, hug: hug,
          fades: true))
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

  // MARK: - The panel

  /// `below` is the safe area under the panel, the home indicator's, which its fill runs on
  /// through.
  private func panelView(_ panel: SiteFinderPanel, below: Double) -> some View {
    VStack(spacing: 0) {
      VStack(spacing: 0) {
        if map.hasMap {
          handle(panel).modifier(FadesInIsland(drag: drag, panel: panel, hug: hug))
        }
        Group {
          if let opened = model.opened {
            IslandHead(drag: drag) {
              siteHead(opened)
            } island: {
              siteIslandHead(opened)
            }
          } else {
            HStack(spacing: 8) {
              searchField
              if typing { closeSearchButton }
            }
          }
        }
        // The handle stands in the top 16, so the search box is as far from every edge.
        .padding(.horizontal, 16)
        .padding(.top, map.hasMap ? 0 : 16)
        .padding(.bottom, 16)
      }
      .contentShape(Rectangle())
      .gesture(
        PanelPan(
          isEnabled: map.hasMap, onChanged: { drag.follow(-$0) },
          onEnded: { letGo(panel, velocity: -$0) }))
      if let failure = model.locationFailure, model.opened == nil {
        FieldMessage(SiteFinderText.locationFailure(failure))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 16)
          .padding(.bottom, 8)
      }
      ZStack(alignment: .top) {
        // Kept under the site rather than built again, so closing it finds the list as it was.
        list(panel)
          .opacity(model.opened == nil ? 1 : 0)
          .allowsHitTesting(model.opened == nil)
          .accessibilityHidden(model.opened != nil)
        if let opened = model.opened {
          siteBody(opened, panel: panel)
        }
      }
    }
    .modifier(PanelFrame(drag: drag, panel: panel, hasMap: map.hasMap))
    .frame(maxWidth: .infinity)
    .modifier(PanelIsland(drag: drag, panel: panel, isOn: map.hasMap, below: below, hug: hug))
  }

  /// Drags the panel, and steps it for VoiceOver and a tap.
  private func handle(_ panel: SiteFinderPanel) -> some View {
    Capsule()
      .fill(.tertiary)
      .frame(width: 36, height: 5)
      .frame(maxWidth: .infinity, minHeight: 16, maxHeight: 16)
      .contentShape(Rectangle())
      .onTapGesture {
        move(to: drag.target == .half ? .full : .half)
      }
      .accessibilityElement()
      .accessibilityLabel(model.opened == nil ? "List of dive sites" : "Dive site")
      .modifier(HandleValue(drag: drag))
      .accessibilityAdjustableAction { direction in
        let all = SiteFinderPanel.Detent.allCases
        guard let at = all.firstIndex(of: drag.target) else { return }
        switch direction {
        case .increment where at + 1 < all.count: move(to: all[at + 1])
        case .decrement where at > 0: move(to: all[at - 1])
        default: break
        }
      }
  }

  /// Settles the panel at the detent the drag was heading for, the spring starting at the
  /// finger's speed rather than from rest. `velocity` is upward positive.
  private func letGo(_ panel: SiteFinderPanel, velocity: Double) {
    let release = panel.release(from: drag.detent, dragged: drag.dragged, velocity: velocity)
    move(
      to: release.detent,
      on: .interpolatingSpring(.snappy, initialVelocity: release.velocity))
  }

  /// Moves the panel to `target`, laid out at its tallest until it lands rather than resized on
  /// every frame of the way. The map makes room for `target` as the spring sets off and the list
  /// takes it once it lands, so the finder is drawn again at either end of the move and not on
  /// the way.
  private func move(to target: SiteFinderPanel.Detent, on animation: Animation = .snappy) {
    if target != .full { typing = false }
    let number = drag.begin()
    withAnimation(animation) {
      drag.head(to: target)
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
    .modifier(SearchFieldFill(drag: drag, isOn: map.hasMap))
  }

  /// Clears the search and sends the panel back to where it opens.
  private var closeSearchButton: some View {
    closeButton("Close search") {
      model.text = ""
      typing = false
      move(to: .half)
    }
  }

  private func closeButton(_ label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: "xmark")
        .panelRoundButton()
    }
    .accessibilityLabel(label)
    .buttonStyle(.plain)
  }

  // MARK: - An opened site

  /// Where the search stood: the site's mark and tags, name and location, beside the way back to
  /// the list with the host's action under it.
  private func siteHead(_ opened: SiteFinderModel.OpenedSite) -> some View {
    let tags = opened.site?.tags ?? []
    let hasBadges = opened.mark != nil || !tags.isEmpty
    return HStack(alignment: .headFirstLine, spacing: 8) {
      VStack(alignment: .leading, spacing: 4) {
        if hasBadges {
          FlowLayout(spacing: 6) {
            if let mark = opened.mark {
              DiveSiteMarkBadge(mark: mark)
            }
            ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
              BadgeView(tag, style: .teal)
            }
          }
          .alignmentGuide(.headFirstLine) { $0[VerticalAlignment.center] }
        }
        let name = Text(opened.name ?? "")
          .font(.title2.bold())
          .lineLimit(2)
          .accessibilityAddTraits(.isHeader)
        if hasBadges {
          name
        } else {
          name.alignmentGuide(.headFirstLine) { $0[VerticalAlignment.center] }
        }
        if let location = opened.location, !location.isEmpty {
          Text(location)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      VStack(spacing: 8) {
        // Its middle on the head's first line, so the badges stand as far below the handle as
        // its ×.
        closeButton("Close dive site") { model.closeSite() }
          .alignmentGuide(.headFirstLine) { $0[VerticalAlignment.center] }
        siteAction(opened)
      }
    }
  }

  /// The opened site in the island: its name on one line beside the way back to the list, in the
  /// height the search box takes. A tap opens it again.
  private func siteIslandHead(_ opened: SiteFinderModel.OpenedSite) -> some View {
    HStack(spacing: 8) {
      Text(opened.name ?? "")
        .font(.headline)
        .lineLimit(1)
        .accessibilityAddTraits(.isHeader)
        .frame(maxWidth: .infinity, alignment: .leading)
      closeButton("Close dive site") { model.closeSite() }
    }
    .padding(.leading, 6)
    .contentShape(Rectangle())
    .onTapGesture { move(to: .half) }
    .accessibilityAction(named: "Show dive site") { move(to: .half) }
  }

  private func siteBody(_ opened: SiteFinderModel.OpenedSite, panel: SiteFinderPanel)
    -> some View
  {
    ScrollView {
      site(opened)
        .background {
          if map.hasMap {
            PanelDragFromScrollTop(
              roomAbove: { drag.roomAbove(in: panel) }, onChanged: { drag.follow(-$0) },
              onEnded: { letGo(panel, velocity: -$0) })
          }
        }
    }
    // Another site opens at its top, rather than where the last one was scrolled to.
    .id(opened.uuid)
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
            roomAbove: { drag.roomAbove(in: panel) }, onChanged: { drag.follow(-$0) },
            onEnded: { letGo(panel, velocity: -$0) })
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
        if let site = model.choose(item) { onSite(site) }
      } label: {
        SiteFinderRow(content: SiteFinderRowContent(row, units: units))
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

extension SiteFinderView where Site == EmptyView, SiteAction == EmptyView {
  /// The dive form's finder, which opens no site in its panel.
  init(
    model: SiteFinderModel, map: MapStyleModel, units: UnitSystem,
    onSite: @escaping (DiveSiteLookupItem) -> Void = { _ in },
    onLongPress: ((DeviceLocation) -> Void)? = nil,
    offlineRows: ((String) -> [FormPickerRow])? = nil,
    onOfflineRow: @escaping (FormPickerRow) -> Void = { _ in },
    @ToolbarContentBuilder bar: @escaping () -> Bar
  ) {
    self.init(
      model: model, map: map, units: units, onSite: onSite, onLongPress: onLongPress,
      offlineRows: offlineRows, onOfflineRow: onOfflineRow, site: { _ in EmptyView() },
      siteAction: { _ in EmptyView() }, bar: bar)
  }
}

/// Moves what it modifies with the panel's top edge, which is `foot` less the panel's height
/// from where it sits: the panel is placed from the top of the finder, the controls riding on
/// it from the bottom. Only this reads how far the panel is dragged and how tall it stands on the
/// way, so a frame of the move draws nothing else again.
private struct RidesPanel: ViewModifier {
  let drag: SiteFinderPanelDrag
  let panel: SiteFinderPanel
  /// The detent a panel that does not move stands at.
  var pinned: SiteFinderPanel.Detent?
  var foot = 0.0
  /// The safe area under the panel, which the island floats into.
  let below: Double
  /// How far the island closes in on what it holds.
  let hug: Double
  /// Fades out above the half the panel opens to, as the controls over the map do. They ride on
  /// the island's top rather than the panel's frame.
  var fades = false

  func body(content: Content) -> some View {
    let height = pinned.map { panel.height($0) } ?? drag.height(in: panel)
    let opacity = fades ? panel.controlsOpacity(shown: height) : 1
    let share = panel.islandShare(shown: height)
    let drop =
      PanelIsland.drop(below: below, share: share, hug: hug) + (fades ? hug * share : 0)
    content
      // Moves as one: each view's position would otherwise animate on its own, and one put in
      // while the panel slides — a site's tags as its read lands — would stand still at the end.
      .geometryGroup()
      .offset(y: foot - height + drop)
      .opacity(opacity)
      .allowsHitTesting(opacity > 0)
      .accessibilityHidden(opacity == 0)
  }
}

/// The panel's outline: a sheet whose fill runs on under the home indicator, or at its lowest an
/// island floating clear of the screen's edges, rounded all round, as the search box alone. Reads
/// how far the panel is dragged, so it is drawn again on every frame of a move, as ``RidesPanel``
/// is; its width changes only within ``SiteFinderPanel/islandSpan`` of the lowest.
private struct PanelIsland: ViewModifier {
  let drag: SiteFinderPanelDrag
  let panel: SiteFinderPanel
  /// Over a map; the panel with no map stands at its tallest, a sheet.
  let isOn: Bool
  /// The safe area under the panel, the home indicator's.
  let below: Double
  /// How far the island closes in from the panel's edges on what it holds.
  let hug: Double

  /// What the island stands clear of the screen's sides and its foot by: the panel's content
  /// inset, so the search box alone stands where it stood on the panel.
  static let margin = 16.0
  /// The search box's room inside the panel, which the island closes in by, leaving the box alone.
  static let searchHug = 16.0

  /// How far the panel, and what rides on it, moves down from its laid-out place as an island
  /// `share` of the way, so that the island's foot stands ``margin`` above the screen's.
  static func drop(below: Double, share: Double, hug: Double) -> Double {
    (below - margin + hug) * share
  }

  private static var sheetRadius: Double {
    if #available(iOS 26, *) { 26 } else { 12 }
  }

  func body(content: Content) -> some View {
    let shown = isOn ? drag.height(in: panel) : panel.height(.full)
    let share = isOn ? panel.islandShare(shown: shown) : 0
    let island = SiteFinderPanel.collapsedHeight / 2 - hug
    // Runs on under a panel that lands a little short of its height, or a spring that carries its
    // foot above the screen's.
    let runOn = (1 - share) * (below + 40)
    let shape = PanelOutline(
      height: shown + runOn, inset: hug * share,
      topRadius: Self.sheetRadius + (island - Self.sheetRadius) * share,
      bottomRadius: island * share)
    // An island that holds the search box alone leaves the box's glass on the map, no panel
    // under it.
    let bare = hug > 0 ? share : 0
    content
      .clipShape(shape)
      // Touches land only where the panel is drawn, so the map takes them around the search box.
      .contentShape(shape)
      .background {
        shape
          .fill(Color.panelFill.opacity(1 - bare))
          .shadow(
            color: .black.opacity((0.15 + 0.05 * share) * (1 - bare)), radius: 8,
            y: -2 + 4 * share)
      }
      .padding(.horizontal, (Self.margin - hug) * share)
  }
}

/// The search box's fill: on the panel, the fill a field takes on it; once the panel heads for the
/// island, where the box stands alone on the map, the glass of the map's other controls.
private struct SearchFieldFill: ViewModifier {
  let drag: SiteFinderPanelDrag
  let isOn: Bool

  // One view whichever fill it takes: built again, the field would lose the focus a tap on the
  // island gives it as the panel opens.
  func body(content: Content) -> some View {
    let glass = isOn && drag.target == .collapsed
    if #available(iOS 26, *) {
      content
        .background(Color(.secondarySystemGroupedBackground).opacity(glass ? 0 : 1), in: Capsule())
        .glassEffect(glass ? .regular.interactive() : .identity, in: Capsule())
    } else {
      content.background(
        glass
          ? AnyShapeStyle(.regularMaterial)
          : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
        in: Capsule())
    }
  }
}

/// Fades the handle out as the panel closes in on the search box, which then stands alone.
private struct FadesInIsland: ViewModifier {
  let drag: SiteFinderPanelDrag
  let panel: SiteFinderPanel
  let hug: Double

  func body(content: Content) -> some View {
    let share = hug > 0 ? panel.islandShare(shown: drag.height(in: panel)) : 0
    content
      .opacity(1 - share)
      .allowsHitTesting(share < 1)
      .accessibilityHidden(share == 1)
  }
}

/// A rectangle `height` tall from the top of its frame, which the panel's frame outruns while it
/// moves, drawn `inset` in from every side, with its own top and bottom corners.
private nonisolated struct PanelOutline: Shape {
  var height: Double
  var inset: Double
  var topRadius: Double
  var bottomRadius: Double

  var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, Double>>
  {
    get { AnimatablePair(AnimatablePair(height, inset), AnimatablePair(topRadius, bottomRadius)) }
    set {
      height = newValue.first.first
      inset = newValue.first.second
      topRadius = newValue.second.first
      bottomRadius = newValue.second.second
    }
  }

  func path(in rect: CGRect) -> Path {
    let outline = CGRect(
      x: rect.minX + inset, y: rect.minY + inset, width: max(0, rect.width - 2 * inset),
      height: max(0, height - 2 * inset))
    let most = min(outline.width, outline.height) / 2
    let top = min(topRadius, most)
    let bottom = min(bottomRadius, most)
    return UnevenRoundedRectangle(
      topLeadingRadius: top, bottomLeadingRadius: bottom, bottomTrailingRadius: bottom,
      topTrailingRadius: top, style: .continuous
    ).path(in: outline)
  }
}

/// An opened site's head: in full, or as one line once the panel is heading for the island, which
/// has room for no more.
private struct IslandHead<Full: View, Island: View>: View {
  let drag: SiteFinderPanelDrag
  @ViewBuilder let full: () -> Full
  @ViewBuilder let island: () -> Island

  var body: some View {
    if drag.target == .collapsed {
      island()
    } else {
      full()
    }
  }
}

/// The panel's height: its detent's at rest, its tallest while it moves. Read here rather than in
/// the finder, which a finger's first pull would otherwise draw again.
private struct PanelFrame: ViewModifier {
  let drag: SiteFinderPanelDrag
  let panel: SiteFinderPanel
  let hasMap: Bool

  func body(content: Content) -> some View {
    content.frame(
      height: hasMap && !drag.isMoving ? panel.height(drag.detent) : panel.height(.full),
      alignment: .top)
  }
}

/// What VoiceOver says the handle is at: where the panel is heading, so a step reads back at
/// once.
private struct HandleValue: ViewModifier {
  let drag: SiteFinderPanelDrag

  func body(content: Content) -> some View {
    let spoken =
      switch drag.target {
      case .collapsed: "Collapsed"
      case .half: "Half screen"
      case .full: "Full screen"
      }
    content.accessibilityValue(spoken)
  }
}

/// One row of the finder's list: a site with its distance, mark and credit, or a place with how
/// many sites are near it.
private struct SiteFinderRow: View {
  let content: SiteFinderRowContent

  var body: some View {
    HStack(alignment: .nameCentre, spacing: 12) {
      Image(content.isPlace ? Icon.mapPin : Icon.diveSite)
        .alignmentGuide(.nameCentre) { $0[VerticalAlignment.center] }
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      // The credit sits outside the distance's row, so it runs on under the distance rather
      // than wrapping in the narrower column beside it.
      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .top, spacing: 12) {
          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
              Text(content.title).foregroundStyle(Color.primary)
                .alignmentGuide(.nameCentre) { $0[VerticalAlignment.center] }
              if let mark = content.mark {
                DiveSiteMarkBadge(mark: mark)
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

extension VerticalAlignment {
  /// The middle of an opened site's first line — its badges, else its name — which its close
  /// button is centred on.
  private enum HeadFirstLine: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat {
      context[VerticalAlignment.top]
    }
  }

  fileprivate static let headFirstLine = VerticalAlignment(HeadFirstLine.self)

  /// The middle of a row's name, which its icon is centred on however many lines follow.
  private enum NameCentre: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat {
      context[VerticalAlignment.top]
    }
  }

  fileprivate static let nameCentre = VerticalAlignment(NameCentre.self)
}

/// The dive form's touched point: the site, its mark and credit, and the way to put it on the dive.
private struct SiteFinderPointSheet: View {
  let point: SiteFinderPoint
  let onChoose: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      PickerRowLabel(row: FormPickerRow(point.lookupItem), showsCredit: true)
      Button("Add to dive", action: onChoose)
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
      map: MapStyleModel(session: session), units: .metric,
      bar: { ToolbarItem(placement: .topBarTrailing) { Button("Add", systemImage: "plus") {} } })
  }
  .environment(session)
}
