import OpenDivingKit
import SwiftUI

/// The web's *New Dive Site* dialog, plus *Use my location*: queues the site and hands back its
/// ref, or reopens a queued create the server refused (`failedItem`) and queues it again. Its
/// *Search location* can hand back a site the diver already has instead, and nothing is made.
struct NewDiveSiteSheet: View {
  let failedItem: UUID?
  let onCreated: (RecordRef) -> Void
  var locator: any LocationProvider = CoreLocationProvider()

  @Environment(Session.self) private var session

  init(failedItem: UUID? = nil, onCreated: @escaping (RecordRef) -> Void) {
    self.failedItem = failedItem
    self.onCreated = onCreated
  }

  var body: some View {
    DiveSiteSheetForm(
      model: RecordSheetModel(
        outbox: OutboxModel(session: session), values: DiveSiteFormValues(),
        failedItem: failedItem),
      units: RecordEntryUnits(session: session), map: MapStyleModel(session: session),
      session: session, locator: locator, onCreated: onCreated)
  }
}

/// The dive site form as a screen of its own: the *Sites* tab's new site, a site's page's edit,
/// or a queued edit the server refused.
struct DiveSiteFormView: View {
  let mode: RecordFormMode<DiveSiteRead>
  /// The site was deleted from the form, which leaves the page it was opened from nothing to show.
  var onDeleted: () -> Void = {}

  @Environment(Session.self) private var session

  var body: some View {
    switch mode {
    case .create:
      form(RecordSheetModel(outbox: OutboxModel(session: session), values: DiveSiteFormValues()))
    case .edit(let site):
      form(edit(site, failedItem: nil))
    case .failed(let item, let uuid):
      RecordFormLoader {
        try await session.requireClient().diveSite(uuid)
      } content: { site in
        form(edit(site, failedItem: item))
      }
    }
  }

  private func edit(_ site: DiveSiteRead, failedItem: UUID?) -> RecordSheetModel<DiveSiteFormValues>
  {
    RecordSheetModel(
      outbox: OutboxModel(session: session), editing: .server(site.uuid),
      read: DiveSiteFormValues(editing: site), failedItem: failedItem)
  }

  private func form(_ model: RecordSheetModel<DiveSiteFormValues>) -> some View {
    DiveSiteSheetForm(
      model: model, units: RecordEntryUnits(session: session),
      map: MapStyleModel(session: session), session: session, locator: CoreLocationProvider(),
      isPushed: true, onCreated: { _ in }, onDeleted: onDeleted)
  }
}

private struct DiveSiteSheetForm: View {
  @State var model: RecordSheetModel<DiveSiteFormValues>
  @State var units: RecordEntryUnits
  @State var map: MapStyleModel
  let session: Session
  let locator: any LocationProvider
  var isPushed = false
  let onCreated: (RecordRef) -> Void
  var onDeleted: () -> Void = {}

  @State private var invalid: Set<String> = []
  @State private var lookup = PositionLookup()
  @State private var searching = false
  @State private var locating = false
  @State private var locationFailure: LocationFailure?
  /// The registry entry the last catalogue pick here added, which the next pick replaces.
  @State private var pickedEntry: ExternalIdWrite?
  @Environment(\.dismiss) private var dismiss
  @FocusState private var locationFocused: Bool

  private static let tagsField = "tags"

  var body: some View {
    ScrollViewReader { proxy in
      RecordSheetForm(
        title: model.isEditing ? "Edit Dive Site" : "New Dive Site",
        isReopened: model.isReopened, createLabel: "Create dive site", isPushed: isPushed,
        failure: model.failure, saveError: model.saveError, deletion: deletion, save: save
      ) {
        Section {
          TextBox(
            label: "Name *", placeholder: "e.g. Blue Hole", text: $model.values.name,
            message: model.message("name"))
        }
        OtherNamesField(names: $model.values.otherNames)
        Section {
          VStack(alignment: .leading, spacing: 6) {
            FieldLabel("Location")
              .focusesOnTap($locationFocused)
            HStack {
              TextField(
                "Location", text: locationName, prompt: Text("e.g. Dahab, South Sinai, Egypt")
              )
              .labelsHidden()
              .focused($locationFocused)
              Button {
                searching = true
              } label: {
                Label("Search location", icon: .mapSearch)
              }
              .labelStyle(.iconOnly)
              .buttonStyle(.borderless)
            }
            FieldMessage(model.message("location", member: "name"))
          }
          CoordinateFields(
            latitude: $model.values.latitude, longitude: $model.values.longitude,
            latitudeMessage: model.message("latitude"),
            longitudeMessage: model.message("longitude"),
            hint: CoordinateHint.diveSite(hasMap: map.hasMap), onPlaced: place)
          Button(locating ? "Finding your location…" : "Use my location", systemImage: "location") {
            Task { await useMyLocation() }
          }
          .accentRow()
          .disabled(locating)
          FieldMessage(locationFailure?.message(hasMap: map.hasMap))
          PinMap(
            style: map.shown, name: "the dive site", latitude: model.values.latitude,
            longitude: model.values.longitude,
            credit: lookup.credit(
              latitude: model.values.latitude, longitude: model.values.longitude),
            onPick: place)
        }
        if !model.values.externalIds.isEmpty {
          Section {
            ForEach(model.values.externalIds, id: \.self) { entry in
              Text("\(ExternalIdRegistry.label(entry.registry)) \(entry.identifier)")
                .swipeToDelete { model.values.externalIds.removeAll { $0 == entry } }
            }
          } header: {
            FormSectionHeader(title: "In Other Registries", icon: .globe)
          }
        }
        Section {
          RecordMeasuredField(
            label: "Depth from", key: "depth_from", measure: .depth, units: units.units(.depth),
            example: 5, value: $model.values.depthFrom, invalid: $invalid,
            message: model.message("depth_from"), onToggle: { units.toggle(.depth) })
          RecordMeasuredField(
            label: "Depth to", key: "depth_to", measure: .depth, units: units.units(.depth),
            example: 30, value: $model.values.depthTo, invalid: $invalid,
            message: model.message("depth_to"), onToggle: { units.toggle(.depth) })
          Picker("Water type", selection: $model.values.waterType) {
            Text("Not recorded").tag(String?.none)
            ForEach(FormVocabulary.waterTypes, id: \.self) { type in
              Text(VocabularyLabels.waterType(type)).tag(Optional(type))
            }
          }
          RecordMeasuredField(
            label: "Altitude", key: "altitude", measure: .altitude,
            units: units.units(.altitude), example: 372, value: $model.values.altitudeMeters,
            invalid: $invalid,
            message: model.message("altitude"), onToggle: { units.toggle(.altitude) },
            allowsNegative: true)
        }
        Section {
          ForEach(FormVocabulary.entryTypes, id: \.self) { entry in
            Toggle(
              VocabularyLabels.entryType(entry),
              isOn: Binding(
                get: { model.values.entryTypes.contains(entry) },
                set: { model.values.setEntryType(entry, $0) })
            )
            .tint(.brandTeal)
          }
        } header: {
          FormSectionHeader(title: "Entry Types", icon: .wavesArrowDown)
        }
        Section {
          TagsField(
            tags: model.values.tags, error: model.message("tags"),
            onAdd: { model.values.addTag($0) },
            onRemove: { model.values.removeTag($0) }
          )
          .id(Self.tagsField)
          NotesField(
            placeholder: "Any notes about this dive site...", text: $model.values.notes,
            error: model.message("notes"))
        } header: {
          FormSectionHeader(group: .notes)
        }
      }
      .followsAddedTags(count: model.values.tags.count, id: Self.tagsField, proxy: proxy)
    }
    .showsMapStyle(map)
    .sheet(isPresented: $searching) {
      LocationSearchSheet(
        latitude: model.values.latitude, longitude: model.values.longitude,
        location: model.values.location, onUse: use,
        onTakeHeldSite: model.isReopened
          ? nil
          : { uuid in
            onCreated(.server(uuid))
            dismiss()
          })
    }
  }

  /// The box shows the place's name; typing replaces the place with a name alone, and
  /// emptying it clears the place.
  private var locationName: Binding<String> {
    Binding(
      get: { model.values.location?.name ?? "" },
      set: { text in
        let typed = String(text.prefix(PlaceSearch.maxLocationNameLength))
        model.values.location =
          typed.trimmingCharacters(in: .whitespaces).isEmpty ? nil : LocationWrite(name: typed)
      })
  }

  /// A position that arrived without a name — tapped, pasted, or the phone's own — and the
  /// geocoder asked what is there.
  private func place(_ latitude: String, _ longitude: String) {
    model.values.latitude = latitude
    model.values.longitude = longitude
    Task {
      await lookup.lookUp(
        session: session, latitude: latitude, longitude: longitude,
        current: { (model.values.latitude, model.values.longitude, model.values.location) },
        apply: { model.values.location = $0 })
    }
  }

  private func useMyLocation() async {
    locating = true
    locationFailure = nil
    defer { locating = false }
    do {
      let here = try await locator.currentLocation()
      place(PinMap.text(here.latitude), PinMap.text(here.longitude))
    } catch {
      locationFailure = error
    }
  }

  /// What *Search location* settled on fills the position and the Location wholesale; a
  /// catalogue site names the site too and adds its registry entry.
  private func use(_ searched: SearchedLocation) {
    model.values.latitude = searched.latitude
    model.values.longitude = searched.longitude
    let location = searched.location
    lookup.adopt(
      latitude: searched.latitude, longitude: searched.longitude,
      credit: location == nil ? nil : searched.credit)
    model.values.location = location
    guard let site = searched.site else { return }
    model.values.name = site.name
    let picked = PlaceSearch.pickExternalId(
      model.values.externalIds, replacing: pickedEntry, with: site.externalId)
    model.values.externalIds = picked.externalIds
    pickedEntry = picked.added
  }

  private func save() -> Bool {
    guard invalid.isEmpty, let ref = model.save() else { return false }
    onCreated(ref)
    return true
  }

  private var deletion: RecordDeletion? {
    guard model.canDelete else { return nil }
    return RecordDeletion(
      title: "Delete dive site", message: RecordDeletionText.diveSite, delete: model.delete,
      onDeleted: onDeleted)
  }
}

#Preview {
  NewDiveSiteSheet { _ in }
    .environment(Session.stub(transport: StubTransport(routes: [:])))
}
