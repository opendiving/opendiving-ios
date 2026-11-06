import CoreLocation
import OpenDivingKit
import SwiftUI

/// What a Commons record picked in the search becomes, which follows where the site form was
/// opened. Choosing it creates nothing.
struct CommonsOffer {
  let label: (DiveSiteLookupItem) -> String
  let take: (DiveSiteLookupItem) -> Void
}

/// Where a place is found, full screen: a map to tap, and under it a search that also takes
/// pasted coordinates and a button for the phone's own position. Focusing the search slides it up
/// over the map, as Maps does. Without a map the search and the button still place it. The form
/// is touched only by the top bar's button: *Use location*, or *No location* once nothing is
/// picked.
struct LocationPickerScreen: View {
  let initial: PickedLocation
  let search: PlaceSearchModel
  let map: MapStyleModel
  /// See ``LocationPickerModel``: a pin with no place name is of no use to a trip part.
  var needsPlace = false
  /// Nil lists places alone: an edit, or a form reopened on a refused create, has a record of
  /// the diver's to place, which a Commons record neither fills nor replaces.
  var commonsOffer: CommonsOffer?
  let onUse: (PickedLocation) -> Void

  @Environment(Session.self) private var session

  var body: some View {
    LocationPickerForm(
      model: LocationPickerModel(
        session: session, search: search, initial: initial, needsPlace: needsPlace,
        locator: CoreLocationProvider()),
      map: map, units: session.units, commonsOffer: commonsOffer, onUse: onUse)
  }
}

private struct LocationPickerForm: View {
  @State var model: LocationPickerModel
  let map: MapStyleModel
  let units: UnitSystem
  let commonsOffer: CommonsOffer?
  let onUse: (PickedLocation) -> Void

  /// The search has slid up over the map. Apart from `typing`, since the search key puts the
  /// keyboard away and leaves the list to read.
  @State private var isSearchOpen = false
  @GestureState(resetTransaction: Transaction(animation: Self.slide))
  private var dragged = 0.0
  @FocusState private var typing: Bool
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottom) {
        // Up here because the panel below grows with the search, and the keyboard lifts it.
        ZStack(alignment: .topTrailing) {
          backdrop
            .onGeometryChange(for: CGSize.self) {
              $0.size
            } action: {
              model.viewport = (width: $0.width, height: $0.height)
            }
          if let credit = map.shown?.credit {
            MapCredit(credit: credit)
              .padding(8)
          }
        }
        panel
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbar(isSearchOpen ? .hidden : .visible, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          ToolbarConfirmButton(
            title: model.isEmpty ? "No location" : "Use location",
            fill: model.isEmpty ? .dangerFill : .brandTeal
          ) {
            onUse(model.used)
            dismiss()
          }
          .disabled(!model.canUse)
        }
      }
    }
    .task {
      // A name with no position opens on its own search.
      if !model.query.isEmpty { isSearchOpen = true }
      await model.start()
    }
    .task(id: model.query) {
      await model.search.search(model.query, near: model.position, units: units)
    }
    .onChange(of: model.query) { old, new in
      Task {
        if await model.queryChanged(from: old, to: new) { closeSearch() }
      }
    }
    .onChange(of: typing) { _, typing in
      if typing { withAnimation(Self.slide) { isSearchOpen = true } }
    }
  }

  @ViewBuilder private var backdrop: some View {
    if let style = map.shown {
      MapLibreView(
        styleJSON: style.styleJSON, pins: model.pin.map { [$0] } ?? [], camera: model.camera,
        onCameraChange: { model.moved(to: $0) }, onTap: place
      )
      .accessibilityLabel("Map. Tap to place the location.")
      .ignoresSafeArea()
    } else {
      Color(.systemGroupedBackground)
        .ignoresSafeArea()
    }
  }

  /// One panel that grows rather than a sheet over it, so the box keeps its focus on the way up.
  private var panel: some View {
    VStack(spacing: 8) {
      if isSearchOpen {
        grabber
      } else {
        selection
        if let failure = model.failure {
          FieldMessage(failure.message(hasMap: map.hasMap))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .pickerCard()
        }
      }
      HStack(spacing: 8) {
        searchField
        if isSearchOpen {
          closeButton
        } else {
          locateButton
        }
      }
      if isSearchOpen {
        results
          .transition(.opacity)
      }
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 8)
    .frame(maxHeight: isSearchOpen ? .infinity : nil, alignment: .top)
    .background {
      UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
        .fill(.thickMaterial)
        .opacity(isSearchOpen ? 1 : 0)
        .ignoresSafeArea(edges: .bottom)
    }
    .offset(y: max(dragged, 0))
  }

  private var grabber: some View {
    Capsule()
      .fill(.tertiary)
      .frame(width: 36, height: 5)
      .frame(maxWidth: .infinity, minHeight: 20)
      .contentShape(Rectangle())
      .gesture(
        DragGesture()
          .updating($dragged) { value, dragged, _ in
            dragged = value.translation.height
          }
          .onEnded { value in
            if value.translation.height > Self.closingDrag { closeSearch() }
          }
      )
      .accessibilityHidden(true)
  }

  private var closeButton: some View {
    Button {
      model.query = ""
      closeSearch()
    } label: {
      Image(systemName: "xmark")
        .frame(width: Self.controlHeight, height: Self.controlHeight)
        .contentShape(Circle())
    }
    .accessibilityLabel("Close search")
    .buttonStyle(.plain)
    .pickerControl(in: Circle())
  }

  private var searchField: some View {
    @Bindable var model = model
    return HStack(spacing: 8) {
      Image(Icon.mapSearch)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      TextField("Search", text: $model.query, prompt: Text(model.search.text.placeholder))
        .autocorrectionDisabled()
        .submitLabel(.search)
        .focused($typing)
        .onSubmit {
          Task {
            if await model.submit() { closeSearch() }
          }
        }
      if !model.query.isEmpty {
        Button("Clear search", systemImage: "xmark.circle.fill") { model.query = "" }
          .labelStyle(.iconOnly)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 14)
    .frame(height: Self.controlHeight)
    .pickerControl(in: Capsule())
  }

  private var locateButton: some View {
    Button {
      typing = false
      Task { await model.useMyLocation() }
    } label: {
      Group {
        if model.isLocating {
          ProgressView()
        } else {
          Image(Icon.locateFixed)
        }
      }
      .frame(width: Self.controlHeight, height: Self.controlHeight)
      .contentShape(Circle())
    }
    .accessibilityLabel(model.isLocating ? "Finding your location" : "Use my location")
    .accentRow()
    .buttonStyle(.plain)
    .disabled(model.isLocating)
    .pickerControl(in: Circle())
  }

  /// The search's rows, or the line saying why there are none, with the credits they owe.
  private var results: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        switch model.search.state {
        case .idle: EmptyView()
        case .tooLong: note(model.search.text.queryTooLong)
        case .searching: ProgressView().frame(maxWidth: .infinity)
        case .noMatches: note(model.search.text.noMatches(hasMap: map.hasMap))
        case .failed: note(model.search.text.searchError(hasMap: map.hasMap))
        case .results(let rows, let hasMore):
          resultRows(rows)
          if hasMore { note("More matches than shown - keep typing to narrow.") }
        }
        if !model.search.attributions.isEmpty {
          AttributionLine(credits: model.search.attributions)
        }
      }
      .padding(.top, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .scrollDismissesKeyboard(.immediately)
    .scrollBounceBehavior(.basedOnSize)
  }

  private func resultRows(_ rows: [PlaceSearchRow]) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(rows) { row in
        if row.id != rows.first?.id { Divider() }
        Button {
          closeSearch()
          model.pick(row.pick)
        } label: {
          VStack(alignment: .leading) {
            Text(row.name).foregroundStyle(Color.primary)
            if let hint = row.hint {
              Text(hint).font(.footnote).foregroundStyle(Color.secondary)
            }
          }
          .padding(.vertical, 12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 14)
    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 16))
  }

  /// What the pin says, or the Commons record on offer, and what can be done about it.
  @ViewBuilder private var selection: some View {
    if let offered = model.offered, let commonsOffer {
      selectionCard(removeLabel: "Dismiss \(offered.name)") {
        VStack(alignment: .leading, spacing: 8) {
          PickerRowLabel(row: FormPickerRow(offered), showsCredit: true)
          Button(commonsOffer.label(offered)) {
            commonsOffer.take(offered)
            dismiss()
          }
          .accentRow()
        }
      }
    } else if model.position != nil || model.picked.location != nil {
      selectionCard(removeLabel: "Remove location") {
        VStack(alignment: .leading, spacing: 4) {
          if model.isNaming {
            Text("Finding the place…").foregroundStyle(.secondary)
          } else if let name = model.placeName {
            Text(name)
          }
          if let position = model.position,
            let text = CoordinateFormat.format(
              latitude: position.latitude, longitude: position.longitude)
          {
            Text(text).font(.footnote).foregroundStyle(.secondary)
          }
          if let message = model.unnamedMessage {
            Text(message).font(.footnote).foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private func selectionCard<Content: View>(
    removeLabel: String, @ViewBuilder content: () -> Content
  ) -> some View {
    HStack(alignment: .top, spacing: 8) {
      content()
        .frame(maxWidth: .infinity, alignment: .leading)
      Button {
        model.clear()
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.title3)
          .foregroundStyle(.secondary)
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(removeLabel)
      // A full target that does not make the card taller.
      .padding(-10)
    }
    .padding(12)
    .pickerCard()
  }

  private func note(_ text: String) -> some View {
    Text(text).font(.footnote).foregroundStyle(.secondary)
  }

  /// A tap on the map ends a search before it places anything.
  private func place(_ coordinate: CLLocationCoordinate2D) {
    guard !isSearchOpen else {
      closeSearch()
      return
    }
    Task { await model.tapped(latitude: coordinate.latitude, longitude: coordinate.longitude) }
  }

  /// Back down to the map. The query stays, and focusing the box brings its list back.
  private func closeSearch() {
    typing = false
    withAnimation(Self.slide) { isSearchOpen = false }
  }

  private static let controlHeight = 48.0
  /// How far down the grabber has to come for the search to close.
  private static let closingDrag = 80.0
  private static let slide = Animation.spring(duration: 0.35)
}

extension View {
  /// A control floating on the map: the toolbar's glass, or its material before iOS 26.
  @ViewBuilder fileprivate func pickerControl(in shape: some Shape) -> some View {
    if #available(iOS 26, *) {
      glassEffect(.regular.interactive(), in: shape)
    } else {
      background(.regularMaterial, in: shape)
    }
  }

  /// A card of text over the map, opaque enough to read on any tile.
  fileprivate func pickerCard() -> some View {
    background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  LocationPickerScreen(
    initial: PickedLocation(
      latitude: "28.5722", longitude: "34.5372", location: LocationWrite(name: "Dahab")),
    search: PlaceSearchModel(session: session, finds: .tripPlaces),
    map: MapStyleModel(session: session), onUse: { _ in }
  )
  .environment(session)
}
