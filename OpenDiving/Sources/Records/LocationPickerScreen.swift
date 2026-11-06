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
/// pasted coordinates and a button for the phone's own position. The search itself is a sheet, as
/// in Maps, which is what drags and closes smoothly over a live map. Without a map the search and the button still place it. The form
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

  @State private var isSearchOpen = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottomLeading) {
        backdrop
          .onGeometryChange(for: CGSize.self) {
            $0.size
          } action: {
            model.viewport = (width: $0.width, height: $0.height)
          }
        if let credit = map.shown?.credit {
          MapCredit(credit: credit)
            .padding(.leading, LocationPickerMetrics.textMargin)
            .padding(.bottom, 8)
        }
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
    .sheet(isPresented: $isSearchOpen) {
      LocationSearchSheet(model: model, hasMap: map.hasMap) { isSearchOpen = false }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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
      if model.queryChanged(from: old, to: new) { isSearchOpen = false }
    }
  }

  @ViewBuilder private var backdrop: some View {
    if let style = map.shown {
      MapLibreView(
        styleJSON: style.styleJSON, pins: model.pin.map { [$0] } ?? [], camera: model.camera,
        onCameraChange: { model.moved(to: $0) }, onTap: place,
        onPinDrop: pinDrop
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
      selection
      if let failure = model.failure {
        FieldMessage(failure.message(hasMap: map.hasMap))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 12)
          .padding(.horizontal, LocationPickerMetrics.cardInset)
          .pickerCard()
      }
      HStack(spacing: 8) {
        searchButton
        locateButton
      }
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 8)
  }

  /// Looks like the box, which is in the sheet it opens.
  private var searchButton: some View {
    Button {
      isSearchOpen = true
    } label: {
      HStack(spacing: 8) {
        Image(Icon.search)
          .foregroundStyle(.primary)
          .accessibilityHidden(true)
        Text(model.query.isEmpty ? model.search.text.placeholder : model.query)
          .foregroundStyle(model.query.isEmpty ? .secondary : .primary)
          .lineLimit(1)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, LocationPickerMetrics.fieldInset)
      .frame(height: LocationPickerMetrics.controlHeight)
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .pickerControl(in: Capsule())
  }

  private var locateButton: some View {
    Button {
      Task { await model.useMyLocation() }
    } label: {
      Group {
        if model.isLocating {
          ProgressView()
        } else {
          Image(Icon.locateFixed)
        }
      }
      .frame(
        width: LocationPickerMetrics.controlHeight, height: LocationPickerMetrics.controlHeight
      )
      .contentShape(Circle())
    }
    .accessibilityLabel(model.isLocating ? "Finding your location" : "Use my location")
    .foregroundStyle(.primary)
    .buttonStyle(.plain)
    .disabled(model.isLocating)
    .pickerControl(in: Circle())
  }

  /// What the pin says, or the Commons record on offer, and what can be done about it.
  @ViewBuilder private var selection: some View {
    if let offered = model.offered, let commonsOffer {
      selectionCard(removeLabel: "Dismiss \(offered.name)") {
        VStack(alignment: .leading, spacing: 8) {
          PickerRowLabel(row: FormPickerRow(offered))
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
          if let credit = model.placeCredit {
            AttributionLine(credits: [credit])
          }
        }
      }
    }
  }

  private func selectionCard<Content: View>(
    removeLabel: String, @ViewBuilder content: () -> Content
  ) -> some View {
    HStack(spacing: 8) {
      content()
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { model.centerOnPin() }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Centers the map on it.")
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
    .padding(.vertical, 12)
    .padding(.leading, LocationPickerMetrics.cardInset)
    // A round mark reads as further from the edge than text the same distance away.
    .padding(.trailing, LocationPickerMetrics.cardInset - 4)
    .pickerCard()
  }

  /// A Commons record on offer is not the diver's to move.
  private var pinDrop: ((CLLocationCoordinate2D) -> Void)? {
    guard model.offered == nil else { return nil }
    return { place($0) }
  }

  private func place(_ coordinate: CLLocationCoordinate2D) {
    Task { await model.tapped(latitude: coordinate.latitude, longitude: coordinate.longitude) }
  }
}

/// The search over the map: the box, focused, and what it found. A pick, pasted coordinates or the
/// close button end it, and so does dragging it down, which keeps the query for next time.
private struct LocationSearchSheet: View {
  let model: LocationPickerModel
  let hasMap: Bool
  let onClose: () -> Void

  @FocusState private var typing: Bool

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        searchField
        closeButton
      }
      .padding(.horizontal, 16)
      .padding(.top, 24)
      .padding(.bottom, 8)
      results
    }
    .task { typing = true }
  }

  private var searchField: some View {
    @Bindable var model = model
    return HStack(spacing: 8) {
      Image(Icon.search)
        .foregroundStyle(.primary)
        .accessibilityHidden(true)
      TextField("Search", text: $model.query, prompt: Text(model.search.text.placeholder))
        .autocorrectionDisabled()
        .submitLabel(.search)
        .focused($typing)
        .onSubmit {
          if model.submit() { onClose() }
        }
      if !model.query.isEmpty {
        Button("Clear search", systemImage: "xmark.circle.fill") { model.query = "" }
          .labelStyle(.iconOnly)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, LocationPickerMetrics.fieldInset)
    .frame(height: LocationPickerMetrics.controlHeight)
    .pickerControl(in: Capsule())
  }

  private var closeButton: some View {
    Button {
      model.query = ""
      onClose()
    } label: {
      Image(systemName: "xmark")
        .frame(
          width: LocationPickerMetrics.controlHeight, height: LocationPickerMetrics.controlHeight
        )
        .contentShape(Circle())
    }
    .accessibilityLabel("Close search")
    .buttonStyle(.plain)
    .pickerControl(in: Circle())
  }

  /// The search's rows, or the line saying why there are none, with the credits they owe.
  private var results: some View {
    List {
      Section {
        switch model.search.state {
        case .idle: EmptyView()
        case .tooLong: note(model.search.text.queryTooLong)
        case .searching: ProgressView().frame(maxWidth: .infinity)
        case .noMatches: note(model.search.text.noMatches(hasMap: hasMap))
        case .failed: note(model.search.text.searchError(hasMap: hasMap))
        case .results(let rows, let hasMore):
          ForEach(rows) { row in
            Button {
              onClose()
              model.pick(row.pick)
            } label: {
              VStack(alignment: .leading) {
                Text(row.name).foregroundStyle(Color.primary)
                if let hint = row.hint {
                  Text(hint).font(.footnote).foregroundStyle(Color.secondary)
                }
              }
            }
          }
          if hasMore { note("More matches than shown - keep typing to narrow.") }
        }
      } footer: {
        if !model.search.attributions.isEmpty {
          AttributionLine(credits: model.search.attributions)
        }
      }
    }
    // The sheet's own background, or the list's meets it in a line under the box.
    .scrollContentBackground(.hidden)
    .contentMargins(.top, 8, for: .scrollContent)
    .scrollDismissesKeyboard(.immediately)
  }

  private func note(_ text: String) -> some View {
    Text(text).font(.footnote).foregroundStyle(.secondary)
  }
}

private enum LocationPickerMetrics {
  static let controlHeight = 48.0
  /// The column the screen's text keeps: where the bar draws *Cancel*, which nothing here sets.
  static let textMargin = 32.0
  /// `textMargin` from inside the panel, which starts 16 in.
  static let cardInset = 16.0
  /// The same for the field, whose symbol sits a little inside its own frame.
  static let fieldInset = 15.0
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

  /// A card over the map: a material rather than glass, which iOS 26 draws close to opaque over
  /// dark tiles, with the corners of a form's section, which each system draws its own and neither
  /// names: measured, 26 and 10.
  fileprivate func pickerCard() -> some View {
    let radius: Double
    if #available(iOS 26, *) { radius = 26 } else { radius = 10 }
    return background(.thinMaterial, in: RoundedRectangle(cornerRadius: radius))
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
