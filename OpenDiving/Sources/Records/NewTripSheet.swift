import OpenDivingKit
import SwiftUI

/// The web's *New Trip* dialog — a name, the parts in order, each a place, a stay and dates,
/// the map of their places, the people and notes: queues the trip and hands back its ref, or
/// reopens a queued create the server refused (`failedItem`) and queues it again.
struct NewTripSheet: View {
  let failedItem: UUID?
  let onCreated: (RecordRef) -> Void

  @Environment(Session.self) private var session

  init(failedItem: UUID? = nil, onCreated: @escaping (RecordRef) -> Void) {
    self.failedItem = failedItem
    self.onCreated = onCreated
  }

  var body: some View {
    TripSheetForm(
      model: RecordSheetModel(
        outbox: OutboxModel(session: session), values: TripFormValues(),
        failedItem: failedItem),
      lookups: LookupsModel(session: session),
      places: PlaceSearchModel(session: session, findsSites: false),
      map: MapStyleModel(session: session), units: session.units, onCreated: onCreated)
  }
}

/// The trip form as a screen of its own: the *Trips* tab's new trip, a trip's page's edit, or a
/// queued edit the server refused.
struct TripFormView: View {
  let mode: RecordFormMode<TripRead>
  /// The trip was deleted from the form, which leaves the page it was opened from nothing to show.
  var onDeleted: () -> Void = {}

  @Environment(Session.self) private var session

  var body: some View {
    switch mode {
    case .create:
      form(RecordSheetModel(outbox: OutboxModel(session: session), values: TripFormValues()))
    case .edit(let trip):
      form(edit(trip, failedItem: nil))
    case .failed(let item, let uuid):
      RecordFormLoader {
        try await session.requireClient().trip(uuid)
      } content: { trip in
        form(edit(trip, failedItem: item))
      }
    }
  }

  private func edit(_ trip: TripRead, failedItem: UUID?) -> RecordSheetModel<TripFormValues> {
    RecordSheetModel(
      outbox: OutboxModel(session: session), editing: .server(trip.uuid),
      read: TripFormValues(editing: trip), failedItem: failedItem)
  }

  private func form(_ model: RecordSheetModel<TripFormValues>) -> some View {
    TripSheetForm(
      model: model, lookups: LookupsModel(session: session),
      places: PlaceSearchModel(session: session, findsSites: false),
      map: MapStyleModel(session: session), units: session.units, isPushed: true,
      onCreated: { _ in }, onDeleted: onDeleted)
  }
}

private struct TripSheetForm: View {
  @State var model: RecordSheetModel<TripFormValues>
  @State var lookups: LookupsModel
  @State var places: PlaceSearchModel
  @State var map: MapStyleModel
  let units: UnitSystem
  var isPushed = false
  let onCreated: (RecordRef) -> Void
  var onDeleted: () -> Void = {}

  var body: some View {
    RecordSheetForm(
      title: model.isEditing ? "Edit Trip" : "New Trip", isReopened: model.isReopened,
      createLabel: "Create trip", isPushed: isPushed, failure: model.failure,
      saveError: model.saveError, deletion: deletion, save: save
    ) {
      Section {
        TextBox(
          label: "Name *", placeholder: "e.g. Red Sea Liveaboard 2024", text: $model.values.name,
          message: model.message("name"))
      }
      // Named, or the section takes the spacing of the last part after it.
      .listSectionSpacing(.default)
      if model.values.parts.isEmpty {
        Section {
          Text(
            "No parts yet. Add one for each place the trip went - or one with dates and no place, for a travel day or a week nobody geocoded."
          )
          .font(.footnote)
          .foregroundStyle(.secondary)
        } header: {
          FormSectionHeader(title: "Parts", icon: .mapPin)
        }
        .listSectionSpacing(.custom(8))
      }
      ForEach(model.values.parts.indices, id: \.self) { index in
        TripPartSection(
          part: part(index), index: index,
          contacts: lookups.contacts, places: places, units: units, hasMap: map.hasMap,
          locationMessage: model.message("parts", index: index, member: "location"),
          datesMessage: model.message("parts", index: index, member: "end_date"),
          remove: { model.values.parts.remove(at: index) }
        )
        // *Add a part* stays by the last part, where the next one appears.
        .listSectionSpacing(index == model.values.parts.count - 1 ? .custom(8) : .default)
      }
      Section {
        Button("Add a part", systemImage: "plus") {
          model.values.parts.append(TripPartFormValues())
        }
        .accentRow()
        .disabled(isFull)
        if isFull {
          Text("\(TripFormValues.maxParts) parts maximum - remove one to add another.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        FieldMessage(model.message("parts"))
      } footer: {
        if !places.attributions.isEmpty {
          AttributionLine(credits: places.attributions)
        }
      }
      if let style = map.shown {
        Section {
          PlacesMapView(
            style: style, points: model.values.mapped, label: "Map of the trip's locations"
          )
          .frame(height: 200)
          .clipShape(RoundedRectangle(cornerRadius: 8))
        }
      }
      RecordPeopleField(people: $model.values.people, rows: lookups.people, defaultRole: nil)
      Section {
        NotesField(
          placeholder: "Any notes about this trip...", text: $model.values.notes,
          error: model.message("notes"))
      } header: {
        FormSectionHeader(group: .notes)
      }
    }
    .showsMapStyle(map)
  }

  /// A part by position, read safely: a removed part's section may draw once more after the
  /// list has shrunk under it.
  private func part(_ index: Int) -> Binding<TripPartFormValues> {
    Binding(
      get: {
        model.values.parts.indices.contains(index)
          ? model.values.parts[index] : TripPartFormValues()
      },
      set: { if model.values.parts.indices.contains(index) { model.values.parts[index] = $0 } })
  }

  private var isFull: Bool { model.values.parts.count >= TripFormValues.maxParts }

  private var deletion: RecordDeletion? {
    guard model.canDelete else { return nil }
    return RecordDeletion(
      title: "Delete trip", message: RecordDeletionText.trip, delete: model.delete,
      onDeleted: onDeleted)
  }

  private func save() -> Bool {
    guard let ref = model.save() else { return false }
    onCreated(ref)
    return true
  }
}

/// One part of the trip: its place, found or typed; where the diver stayed; its dates.
private struct TripPartSection: View {
  @Binding var part: TripPartFormValues
  let index: Int
  let contacts: [ContactLookupItem]
  let places: PlaceSearchModel
  let units: UnitSystem
  let hasMap: Bool
  let locationMessage: String?
  let datesMessage: String?
  let remove: () -> Void

  var body: some View {
    Section {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel("Location")
        NavigationLink {
          TripPartPlaceScreen(places: places, units: units) { location in
            part.location = location
          }
        } label: {
          Text(part.location?.name ?? "Search for a place...")
            .foregroundStyle(part.location == nil ? .secondary : .primary)
        }
        if hasMap, let location = part.location, location.mapPoint == nil {
          Text("Not on the map").font(.caption).foregroundStyle(.secondary)
        }
        FieldMessage(locationMessage)
      }
      RecordPicker(
        label: "Accommodation", placeholder: "Select accommodation...",
        searchPrompt: "Search accommodation...",
        addLabel: "Add accommodation...", rows: contacts, selection: $part.accommodation
      ) { made in
        NewContactSheet(roles: ["accommodation"], onCreated: made)
      }
      CalendarDateField(label: "Start date", date: $part.startDate)
      CalendarDateField(label: "End date", date: $part.endDate)
      FieldMessage(datesMessage)
    } header: {
      // Parts are sections, which do not drag; putting them in order stays with the web.
      RemovableSectionHeader(title: "Part \(index + 1)", icon: .mapPin, onRemove: remove)
    }
  }
}

/// The search a part's Location pushes: a place picked, or a name taken as typed.
private struct TripPartPlaceScreen: View {
  let places: PlaceSearchModel
  let units: UnitSystem
  let onUse: (LocationWrite?) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var query = ""

  var body: some View {
    List {
      PlaceSearchSection(
        model: places, query: $query, units: units,
        onPick: { pick in
          if case .geocode(let result) = pick { onUse(PlaceSearch.location(of: result)) }
          dismiss()
        },
        onTypeName: { name in
          onUse(PlaceSearch.typedLocation(name))
          dismiss()
        })
      Section {
        Button("No location", role: .destructive) {
          onUse(nil)
          dismiss()
        }
        .dangerRow()
      }
    }
    .navigationTitle("Location")
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NewTripSheet { _ in }
    .environment(Session.stub(transport: StubTransport(routes: [:])))
}
