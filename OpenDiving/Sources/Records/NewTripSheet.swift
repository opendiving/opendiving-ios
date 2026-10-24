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
      places: PlaceSearchModel(session: session, findsSites: false), units: session.units,
      onCreated: onCreated)
  }
}

private struct TripSheetForm: View {
  @State var model: RecordSheetModel<TripFormValues>
  @State var lookups: LookupsModel
  @State var places: PlaceSearchModel
  let units: UnitSystem
  let onCreated: (RecordRef) -> Void

  var body: some View {
    RecordSheetForm(
      title: "New Trip", createLabel: "Create trip", isReopened: model.isReopened,
      failure: model.failure, saveError: model.saveError, save: save
    ) {
      Section {
        TextBox(
          label: "Name *", placeholder: "e.g. Red Sea Liveaboard 2024", text: $model.values.name,
          message: model.message("name"))
      }
      if model.values.parts.isEmpty {
        Section("Parts") {
          Text(
            "No parts yet. Add one for each place the trip went - or one with dates and no place, for a travel day or a week nobody geocoded."
          )
          .font(.footnote)
          .foregroundStyle(.secondary)
        }
      }
      ForEach(model.values.parts.indices, id: \.self) { index in
        TripPartSection(
          part: part(index), index: index, total: model.values.parts.count,
          contacts: lookups.contacts, places: places, units: units,
          locationMessage: model.message("parts", index: index, member: "location"),
          datesMessage: model.message("parts", index: index, member: "end_date"),
          remove: { model.values.parts.remove(at: index) },
          move: { offset in
            model.values.parts.swapAt(index, index + offset)
          })
      }
      Section {
        Button("Add a part", systemImage: "plus") {
          model.values.parts.append(TripPartFormValues())
        }
        .disabled(isFull)
        if isFull {
          Text("\(TripFormValues.maxParts) parts maximum - remove one to add another.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        FieldMessage(text: model.message("parts"))
      } footer: {
        if !places.attributions.isEmpty {
          AttributionLine(credits: places.attributions)
        }
      }
      Section {
        PlacesMapView(points: mapped)
          .id(mapped)
          .frame(height: 200)
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .accessibilityLabel("Map of the trip's locations")
      }
      PeopleField(people: $model.values.people, rows: lookups.people, defaultRole: nil)
      Section {
        TextBox(
          label: "Notes", placeholder: "Any notes about this trip...",
          text: $model.values.notes, message: model.message("notes"), multiline: true)
      }
    }
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

  private var mapped: [MapPoint] {
    model.values.parts.compactMap { part in
      guard let location = part.location, let latitude = location.latitude,
        let longitude = location.longitude
      else { return nil }
      return MapPoint(name: location.name, latitude: latitude, longitude: longitude)
    }
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
  let total: Int
  let contacts: [ContactLookupItem]
  let places: PlaceSearchModel
  let units: UnitSystem
  let locationMessage: String?
  let datesMessage: String?
  let remove: () -> Void
  let move: (Int) -> Void

  var body: some View {
    Section {
      VStack(alignment: .leading, spacing: 6) {
        Text("Location").font(.subheadline.weight(.medium))
        NavigationLink {
          TripPartPlaceScreen(places: places, units: units) { location in
            part.location = location
          }
        } label: {
          Text(part.location?.name ?? "Search for a place...")
            .foregroundStyle(part.location == nil ? .secondary : .primary)
        }
        if let location = part.location, location.latitude == nil || location.longitude == nil {
          Text("Not on the map").font(.caption).foregroundStyle(.secondary)
        }
        FieldMessage(text: locationMessage)
      }
      RecordPicker(
        label: "Accommodation", placeholder: "Select accommodation...",
        addLabel: "Add accommodation...", rows: contacts, selection: $part.accommodation
      ) { made in
        NewContactSheet(roles: ["accommodation"], onCreated: made)
      }
      CalendarDateField(label: "Start date", date: $part.startDate)
      CalendarDateField(label: "End date", date: $part.endDate)
      FieldMessage(text: datesMessage)
      HStack {
        if total > 1 {
          Button("Move up", systemImage: "arrow.up") { move(-1) }
            .disabled(index == 0)
          Button("Move down", systemImage: "arrow.down") { move(1) }
            .disabled(index == total - 1)
        }
        Spacer()
        Button("Remove", systemImage: "trash", role: .destructive, action: remove)
          .accessibilityLabel("Remove part \(index + 1)")
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
    } header: {
      Text("Part \(index + 1)")
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
