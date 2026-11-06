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
/// pasted coordinates and a button for the phone's own position. Without a map the search and the
/// button still place it. The form is touched only by *Use location* and *No location*.
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

  @State private var resultsHeight = 0.0
  /// A tap on the map put the list away. The query stays, and focusing the box brings it back.
  @State private var resultsClosed = false
  @FocusState private var typing: Bool
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottomTrailing) {
        backdrop
        if let credit = map.shown?.credit {
          MapCredit(credit: credit)
            .padding(8)
        }
      }
      .onGeometryChange(for: CGSize.self) {
        $0.size
      } action: {
        model.viewport = (width: $0.width, height: $0.height)
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        panel
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          ToolbarConfirmButton(title: "Use location") {
            finish(model.used)
          }
          .disabled(!model.canUse)
        }
      }
    }
    .task { await model.start() }
    .task(id: model.query) {
      await model.search.search(model.query, near: model.position, units: units)
    }
    .onChange(of: model.query) { old, new in
      resultsClosed = false
      Task { await model.queryChanged(from: old, to: new) }
    }
    .onChange(of: typing) { _, typing in
      if typing { resultsClosed = false }
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

  private var panel: some View {
    VStack(spacing: 8) {
      if showsResults {
        results
      } else {
        selection
      }
      if let failure = model.failure {
        FieldMessage(failure.message(hasMap: map.hasMap))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(12)
          .pickerCard()
      }
      HStack(spacing: 8) {
        searchField
        locateButton
      }
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 8)
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
        .onSubmit { Task { await model.submit() } }
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
      resultRows
        .onGeometryChange(for: Double.self) {
          $0.size.height
        } action: {
          resultsHeight = $0
        }
    }
    .scrollBounceBehavior(.basedOnSize)
    .frame(height: min(resultsHeight, Self.maxResultsHeight))
    .pickerCard()
  }

  private var resultRows: some View {
    VStack(alignment: .leading, spacing: 12) {
      switch model.search.state {
      case .idle: EmptyView()
      case .tooLong: note(model.search.text.queryTooLong)
      case .searching: ProgressView().frame(maxWidth: .infinity)
      case .noMatches: note(model.search.text.noMatches(hasMap: map.hasMap))
      case .failed: note(model.search.text.searchError(hasMap: map.hasMap))
      case .results(let rows, let hasMore):
        ForEach(rows) { row in
          Button {
            typing = false
            model.pick(row.pick)
          } label: {
            VStack(alignment: .leading) {
              Text(row.name).foregroundStyle(Color.primary)
              if let hint = row.hint {
                Text(hint).font(.footnote).foregroundStyle(Color.secondary)
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
        if hasMore { note("More matches than shown - keep typing to narrow.") }
      }
      if !model.search.attributions.isEmpty {
        AttributionLine(credits: model.search.attributions)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
  }

  /// What the pin says, or the Commons record on offer, and what can be done about it.
  @ViewBuilder private var selection: some View {
    if let offered = model.offered, let commonsOffer {
      VStack(alignment: .leading, spacing: 8) {
        PickerRowLabel(row: FormPickerRow(offered), showsCredit: true)
        Button(commonsOffer.label(offered)) {
          commonsOffer.take(offered)
          dismiss()
        }
        .accentRow()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .pickerCard()
    } else if model.position != nil || model.canClear {
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
        if model.canClear {
          Button("No location", role: .destructive) {
            finish(PickedLocation())
          }
          .dangerRow()
          .padding(.top, 4)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .pickerCard()
    }
  }

  private func note(_ text: String) -> some View {
    Text(text).font(.footnote).foregroundStyle(.secondary)
  }

  private var showsResults: Bool { !resultsClosed && model.search.state != .idle }

  /// A tap on the map ends a search before it places anything.
  private func place(_ coordinate: CLLocationCoordinate2D) {
    guard !typing, !showsResults else {
      typing = false
      resultsClosed = true
      return
    }
    Task { await model.tapped(latitude: coordinate.latitude, longitude: coordinate.longitude) }
  }

  private func finish(_ picked: PickedLocation) {
    onUse(picked)
    dismiss()
  }

  private static let controlHeight = 48.0
  private static let maxResultsHeight = 280.0
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
