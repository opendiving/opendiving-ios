import CoreLocation
import OpenDivingKit
import SwiftUI

/// The site finder the sites map is and the dive form's site picker opens: the map full screen
/// under a panel that holds the search and the list, *Your sites* and *Use my location* floating
/// over the map's corner above the panel, and a spinner under the top bar while the list is asked
/// for again. With no map on the instance the panel stands alone, at its tallest. On the sites map
/// a site opened from its row or its point takes the panel's search and list, its pin larger at
/// the middle of the map and the others faded; on the dive form a touched point is named under a
/// sheet. What a row does when chosen, what an opened site shows, and the top bar's buttons, are
/// the host's; the bar draws no background over the map.
struct SiteFinderView<Site: View, SiteAction: View, Bar: ToolbarContent>: View {
  let model: SiteFinderModel
  let map: MapStyleModel
  let units: UnitSystem
  /// What choosing a row or a touched point's sheet does on the dive form; on the sites map either
  /// opens the site in the panel.
  var onSite: (DiveSiteLookupItem) -> Void = { _ in }
  /// A long press on the map, where a site is added.
  var onLongPress: ((DeviceLocation) -> Void)?
  /// What the dive form lists while the search cannot reach the server: the phone's lookup rows.
  var offlineRows: ((String) -> [FormPickerRow])?
  var onOfflineRow: (FormPickerRow) -> Void = { _ in }
  /// What the panel shows of the site the sites map opened.
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
          Color(.systemGroupedBackground).ignoresSafeArea()
        }
        // Placed from the top: with the keyboard up the bottom edge moves, though it is ignored.
        panelView(panel, below: geometry.safeAreaInsets.bottom)
          .modifier(
            RidesPanel(
              drag: drag, panel: panel, pinned: map.hasMap ? nil : .full,
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
    .onChange(of: model.opened?.uuid) { old, new in
      guard map.hasMap else { return }
      // A site opens up from where the list left it, or down off the top where a match was
      // opened from; closed, by its button, the map or *Use my location*, the list comes back
      // where the panel opens, as the search's close leaves it.
      if new == nil || old == nil || drag.target == .collapsed { move(to: .half) }
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

  // MARK: - The map

  /// The detent the map makes room for: at its tallest the panel hides the map, which keeps the
  /// half it had.
  private var mapDetent: SiteFinderPanel.Detent {
    drag.detent == .full ? .half : drag.detent
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
        styleJSON: style.styleJSON, camera: model.camera, glides: model.glides, covered: covered,
        commons: model.yours ? nil : model.points.commons, yours: model.points.yours,
        selected: model.opened?.uuid ?? model.selected?.uuid,
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
      .modifier(RidesPanel(drag: drag, panel: panel, fades: true))
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

  /// `below` is the safe area under the panel, the home indicator's, which its fill runs on
  /// through.
  private func panelView(_ panel: SiteFinderPanel, below: Double) -> some View {
    let shape = UnevenRoundedRectangle(
      topLeadingRadius: Self.panelRadius, topTrailingRadius: Self.panelRadius)
    return VStack(spacing: 0) {
      VStack(spacing: 0) {
        if map.hasMap { handle(panel) }
        Group {
          if let opened = model.opened {
            siteHead(opened)
          } else {
            HStack(spacing: 8) {
              searchField
              if typing { closeSearchButton }
            }
          }
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
  /// every frame of the way. The finder takes the new detent once it lands, so the spring moves
  /// the panel and nothing else.
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
    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
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
        closeButton("Close dive site") { model.closeSite() }
        siteAction(opened)
      }
      // The close button's middle, half its 44 points down, on the head's first line, so the
      // badges stand as far below the handle as its ×.
      .alignmentGuide(.headFirstLine) { _ in 22 }
    }
  }

  private func siteBody(_ opened: SiteFinderModel.OpenedSite, panel: SiteFinderPanel)
    -> some View
  {
    ScrollView {
      site(opened)
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
        switch model.host {
        case .sitesMap: model.open(item)
        case .diveForm: onSite(item.site)
        }
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

/// Moves what it modifies with the panel's top edge, which is `foot` less the panel's height
/// from where it sits: the panel is placed from the top of the finder, the controls riding on
/// it from the bottom. Only this reads how far the panel is dragged and where it is heading, so a
/// move draws nothing else again.
private struct RidesPanel: ViewModifier {
  let drag: SiteFinderPanelDrag
  let panel: SiteFinderPanel
  /// The detent a panel that does not move stands at.
  var pinned: SiteFinderPanel.Detent?
  var foot = 0.0
  /// Fades out above the half the panel opens to, as the controls over the map do.
  var fades = false

  func body(content: Content) -> some View {
    let height = pinned.map { panel.height($0) } ?? drag.height(in: panel)
    let opacity = fades ? panel.controlsOpacity(shown: height) : 1
    content
      // Moves as one: each view's position would otherwise animate on its own, and one put in
      // while the panel slides — a site's tags as its read lands — would stand still at the end.
      .geometryGroup()
      .offset(y: foot - height)
      .opacity(opacity)
      .allowsHitTesting(opacity > 0)
      .accessibilityHidden(opacity == 0)
  }
}

/// The panel's height: its detent's at rest, its tallest while it moves. Read here rather than in
/// the finder, so a move starting lays out the panel without drawing the finder again.
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
/// once. Read here rather than in the finder, which a move starting would draw again.
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
      site: { _ in EmptyView() },
      siteAction: { _ in EmptyView() },
      bar: { ToolbarItem(placement: .topBarTrailing) { Button("Add", systemImage: "plus") {} } })
  }
  .environment(session)
}
