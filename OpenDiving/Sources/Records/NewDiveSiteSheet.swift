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
      units: RecordEntryUnits(session: session), session: session, locator: locator,
      onCreated: onCreated)
  }
}

private struct DiveSiteSheetForm: View {
  @State var model: RecordSheetModel<DiveSiteFormValues>
  @State var units: RecordEntryUnits
  let session: Session
  let locator: any LocationProvider
  let onCreated: (RecordRef) -> Void

  @State private var invalid: Set<String> = []
  @State private var lookup = PositionLookup()
  @State private var searching = false
  @State private var locating = false
  @State private var locationFailure: String?
  /// The registry entry the last catalogue pick here added, which the next pick replaces.
  @State private var pickedEntry: ExternalIdWrite?
  @Environment(\.dismiss) private var dismiss

  private static let coordinateHint =
    "Paste a “27.8506, 34.3136” pair into either field to fill both, or place the site on the map below."

  var body: some View {
    RecordSheetForm(
      title: "New Dive Site", createLabel: "Create dive site", isReopened: model.isReopened,
      failure: model.failure, saveError: model.saveError, save: save
    ) {
      Section {
        TextBox(
          label: "Name *", placeholder: "e.g. Blue Hole", text: $model.values.name,
          message: model.message("name"))
      }
      OtherNamesField(names: $model.values.otherNames)
      Section {
        VStack(alignment: .leading, spacing: 6) {
          Text("Location").font(.subheadline.weight(.medium))
          HStack {
            TextField(
              "Location", text: locationName, prompt: Text("e.g. Dahab, South Sinai, Egypt")
            )
            .labelsHidden()
            Button("Search location", systemImage: "magnifyingglass") { searching = true }
              .labelStyle(.iconOnly)
              .buttonStyle(.borderless)
          }
          FieldMessage(model.message("location", member: "name"))
        }
        CoordinateFields(
          latitude: $model.values.latitude, longitude: $model.values.longitude,
          latitudeMessage: model.message("latitude"),
          longitudeMessage: model.message("longitude"), hint: Self.coordinateHint,
          onPlaced: place)
        Button(locating ? "Finding your location…" : "Use my location", systemImage: "location") {
          Task { await useMyLocation() }
        }
        .disabled(locating)
        FieldMessage(locationFailure)
        PinMap(
          name: "the dive site", latitude: model.values.latitude,
          longitude: model.values.longitude,
          credit: lookup.credit(
            latitude: model.values.latitude, longitude: model.values.longitude),
          onPick: place)
      }
      if !model.values.externalIds.isEmpty {
        Section("In other registries") {
          ForEach(model.values.externalIds, id: \.self) { entry in
            Text("\(ExternalIdRegistry.label(entry.registry)) \(entry.identifier)")
          }
          .onDelete { model.values.externalIds.remove(atOffsets: $0) }
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
          units: units.units(.altitude), example: 372, value: altitude, invalid: $invalid,
          message: model.message("altitude"), onToggle: { units.toggle(.altitude) },
          allowsNegative: true)
      }
      Section("Entry types") {
        ForEach(FormVocabulary.entryTypes, id: \.self) { entry in
          Toggle(VocabularyLabels.entryType(entry), isOn: entryType(entry))
        }
      }
      Section {
        TagsField(
          tags: model.values.tags, error: model.message("tags"), onAdd: addTag,
          onRemove: { tag in model.values.tags.removeAll { $0 == tag } })
      }
      Section {
        TextBox(
          label: "Notes", placeholder: "Any notes about this dive site...",
          text: $model.values.notes, message: model.message("notes"), multiline: true)
      }
    }
    .sheet(isPresented: $searching) {
      LocationSearchSheet(
        latitude: model.values.latitude, longitude: model.values.longitude,
        location: model.values.location, onUse: use,
        onTakeHeldSite: { uuid in
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

  /// The same tag twice, in any case, is one tag.
  private func addTag(_ text: String) {
    let tag = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !tag.isEmpty,
      !model.values.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame })
    else { return }
    model.values.tags.append(tag)
  }

  /// Whole metres, as the column holds them.
  private var altitude: Binding<Double?> {
    Binding(
      get: { model.values.altitude.map(Double.init) },
      // Clamped before the conversion, which traps outside Int's range; anything past the
      // band is still refused by the form's rule, with its sentence.
      set: { model.values.altitude = $0.map { Int(min(max($0.rounded(), -1e9), 1e9)) } })
  }

  private func entryType(_ entry: String) -> Binding<Bool> {
    Binding(
      get: { model.values.entryTypes.contains(entry) },
      set: { on in
        if on {
          if !model.values.entryTypes.contains(entry) { model.values.entryTypes.append(entry) }
        } else {
          model.values.entryTypes.removeAll { $0 == entry }
        }
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
      locationFailure = error.message
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
}

#Preview {
  NewDiveSiteSheet { _ in }
    .environment(Session.stub(transport: StubTransport(routes: [:])))
}
