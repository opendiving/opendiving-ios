import CoreLocation
import OpenDivingKit
import SwiftUI

/// The site finder the Sites tab is and the dive form's site picker opens: the map over the list,
/// the search in the bar the system places, *Your sites*, *Search this area* once the map has
/// moved and *Use my location*. With no map on the instance the list and the search stand alone.
/// What a site does when chosen, and what goes over the list, are the host's.
struct SiteFinderView<Header: View>: View {
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
  @ViewBuilder let header: () -> Header

  var body: some View {
    @Bindable var model = model
    VStack(spacing: 0) {
      if let style = map.shown {
        mapArea(style)
          .containerRelativeFrame(.vertical) { height, _ in height * 0.42 }
      }
      controls
      list
    }
    .background(Color(.systemGroupedBackground))
    .searchable(text: $model.text, prompt: SiteFinderText.searchPrompt)
    .autocorrectionDisabled()
    .showsMapStyle(map)
    .onChange(of: map.hasMap, initial: true) { _, hasMap in model.hasMap = hasMap }
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

  private func mapArea(_ style: MapStyleModel.Shown) -> some View {
    ZStack {
      SiteFinderMap(
        styleJSON: style.styleJSON, camera: model.camera,
        commons: model.yours ? nil : model.points.commons, yours: model.points.yours,
        selected: model.selected,
        onCameraChange: { camera, view, byGesture in
          model.mapMoved(to: camera, showing: view, byGesture: byGesture)
        },
        onPoint: { model.select($0) },
        onLongPress: onLongPress.map { add in
          { add(DeviceLocation(latitude: $0.latitude, longitude: $0.longitude)) }
        }
      )
      .accessibilityLabel("Map of dive sites")
      .onGeometryChange(for: CGSize.self) {
        $0.size
      } action: {
        model.viewport = (width: $0.width, height: $0.height)
      }
      VStack {
        if model.offersSearchThisArea {
          Button(SiteFinderText.searchThisArea) {
            Task { await model.searchThisArea() }
          }
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.primary)
          .padding(.horizontal, 16)
          .frame(height: 36)
          .buttonStyle(.plain)
          .pickerControl(in: Capsule())
          .padding(.top, 12)
        }
        Spacer()
        HStack(alignment: .bottom) {
          MapCredit(credit: style.credit)
          Spacer()
          locateButton
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
      }
    }
    .clipped()
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
      .frame(width: 44, height: 44)
      .contentShape(Circle())
    }
    .accessibilityLabel(model.isLocating ? SiteFinderText.locating : SiteFinderText.useMyLocation)
    .foregroundStyle(.primary)
    .buttonStyle(.plain)
    .disabled(model.isLocating)
    .pickerControl(in: Circle())
  }

  // MARK: - The filter

  private var controls: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Toggle(
          SiteFinderText.yoursLabel,
          isOn: Binding(
            get: { model.yours }, set: { on in Task { await model.setYours(on) } })
        )
        .toggleStyle(.button)
        .buttonStyle(.bordered)
        .tint(model.yours ? Color.brandTeal : Color.secondary)
        Spacer()
        if !map.hasMap {
          Button {
            Task { await model.useMyLocation() }
          } label: {
            Label(SiteFinderText.useMyLocation, icon: .locateFixed)
          }
          .disabled(model.isLocating)
        }
      }
      if let failure = model.locationFailure {
        FieldMessage(SiteFinderText.locationFailure(failure))
      }
    }
    .font(.subheadline)
    .padding(.horizontal)
    .padding(.vertical, 8)
  }

  // MARK: - The list

  private var list: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        header()
        content
      }
      .padding()
    }
    .scrollDismissesKeyboard(.immediately)
    .refreshable { await model.list?.refresh() }
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
        if let lastUpdated = list.lastUpdated {
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

/// One row of the finder's list: a site with its distance, mark and credit, or a place with how
/// many sites are near it.
private struct SiteFinderRow: View {
  let content: SiteFinderRowContent

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(content.isPlace ? Icon.mapPin : Icon.diveSite)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(content.title).foregroundStyle(Color.primary)
          if content.isCommons {
            BadgeView(DiveSiteSummary.commonsLabel, style: .outline) { CommonsMark() }
          }
        }
        if let subtitle = content.subtitle {
          Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
        if let nearby = content.nearby {
          Text(nearby).font(.footnote).foregroundStyle(.secondary)
        }
        if let credit = content.credit {
          AttributionLine(credits: [credit])
        }
      }
      Spacer(minLength: 0)
      if let distance = content.distance {
        Text(distance).font(.subheadline).foregroundStyle(.secondary)
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
      onSite: { _ in }, header: { EmptyView() })
  }
  .environment(session)
}
