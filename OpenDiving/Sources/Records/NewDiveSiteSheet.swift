import OpenDivingKit
import SwiftUI

/// The web's *New Dive Site* dialog: queues the site and hands back its ref, or reopens a queued
/// create the server refused (`failedItem`) and queues it again. Its location picker can hand
/// back a Commons record instead, and nothing is made.
struct NewDiveSiteSheet: View {
  let failedItem: UUID?
  /// Nil where a Commons record has nothing to go on.
  var onCommonsSite: ((DiveSiteLookupItem) -> Void)?
  let onCreated: (RecordRef) -> Void

  @Environment(Session.self) private var session

  init(
    failedItem: UUID? = nil, onCommonsSite: ((DiveSiteLookupItem) -> Void)? = nil,
    onCreated: @escaping (RecordRef) -> Void
  ) {
    self.failedItem = failedItem
    self.onCommonsSite = onCommonsSite
    self.onCreated = onCreated
  }

  var body: some View {
    DiveSiteSheetForm(
      model: RecordSheetModel(
        outbox: OutboxModel(session: session), values: DiveSiteFormValues(),
        failedItem: failedItem),
      units: RecordEntryUnits(session: session), map: MapStyleModel(session: session),
      session: session, onCommonsSite: onCommonsSite, onCreated: onCreated)
  }
}

/// The dive site form as a screen of its own: the *Sites* tab's new site, a site's page's edit,
/// or a queued edit the server refused. A Commons record opens its own form, and one off the
/// diver's list none.
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
      editing(site, failedItem: nil)
    case .failed(let item, let uuid):
      RecordFormLoader {
        try await session.requireClient().diveSite(uuid)
      } content: { site in
        editing(site, failedItem: item)
      }
    }
  }

  @ViewBuilder private func editing(_ site: DiveSiteRead, failedItem: UUID?) -> some View {
    if site.isUnsavedCommons {
      EmptyOrErrorView(
        status: .empty(
          icon: .diveSite, title: "Not on your list",
          message: "This site is no longer on your list, so nothing of it can be changed here."))
    } else if site.isCommons {
      CommonsSiteForm(
        site: site, model: edit(site, failedItem: failedItem), units: session.units,
        onDeleted: onDeleted)
    } else {
      form(edit(site, failedItem: failedItem))
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
      map: MapStyleModel(session: session), session: session, isPushed: true,
      onCreated: { _ in }, onDeleted: onDeleted)
  }
}

private struct DiveSiteSheetForm: View {
  @State var model: RecordSheetModel<DiveSiteFormValues>
  @State var units: RecordEntryUnits
  @State var map: MapStyleModel
  let session: Session
  var isPushed = false
  var onCommonsSite: ((DiveSiteLookupItem) -> Void)?
  let onCreated: (RecordRef) -> Void
  var onDeleted: () -> Void = {}

  @State private var invalid: Set<String> = []
  @State private var lookup = PositionLookup()
  @State private var searching = false
  /// A position typed or pasted into the boxes, waiting for its place's name.
  @State private var enteredPosition: DeviceLocation?
  /// A Commons record went on the list from the search: the form leaves once it has closed.
  @State private var savedFromSearch = false
  @Environment(\.dismiss) private var dismiss

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
          LocationField(
            name: model.values.location?.name,
            message: model.message("location", member: "name")
          ) {
            searching = true
          }
          CoordinateFields(
            latitude: $model.values.latitude, longitude: $model.values.longitude,
            latitudeMessage: model.message("latitude"),
            longitudeMessage: model.message("longitude"), hint: CoordinateHint.diveSite)
          if let style = map.shown {
            PlacesMapView(style: style, points: pins, label: "Map of the dive site")
              .frame(height: 200)
              .clipShape(RoundedRectangle(cornerRadius: 8))
          }
          if let credit = lookup.credit(
            latitude: model.values.latitude, longitude: model.values.longitude)
          {
            AttributionLine(credits: [credit])
          }
        } header: {
          FormSectionHeader(group: .location)
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
        } header: {
          FormSectionHeader(title: "Depth & Water", icon: .waves)
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
        SiteNotesSection(model: model)
      }
      .followsAddedTags(
        count: model.values.tags.count, id: SiteNotesSection.tagsField, proxy: proxy)
    }
    .showsMapStyle(map)
    .onChange(of: position) { _, position in
      let isAnswered = lookup.answers(
        latitude: model.values.latitude, longitude: model.values.longitude)
      enteredPosition = isAnswered ? nil : position
    }
    .task(id: enteredPosition) {
      guard enteredPosition != nil else { return }
      try? await Task.sleep(for: PlaceSearch.debounce)
      guard !Task.isCancelled else { return }
      await nameEnteredPosition()
    }
    .fullScreenCover(
      isPresented: $searching,
      onDismiss: {
        if savedFromSearch { dismiss() }
      },
      content: {
        LocationPickerScreen(
          initial: PickedLocation(
            latitude: model.values.latitude, longitude: model.values.longitude,
            location: model.values.location,
            credit: lookup.credit(
              latitude: model.values.latitude, longitude: model.values.longitude)),
          search: PlaceSearchModel(
            session: session, finds: commonsOffer == nil ? .sitePlaces : .commonsAndPlaces),
          map: map, commonsOffer: commonsOffer, onUse: use)
      })
  }

  private var position: DeviceLocation? {
    PlaceSearch.position(latitude: model.values.latitude, longitude: model.values.longitude)
  }

  private var pins: [MapPoint] {
    position.map {
      [MapPoint(name: "The dive site", latitude: $0.latitude, longitude: $0.longitude)]
    } ?? []
  }

  /// From a dive's picker the record goes on the dive, and from the *Sites* tab on the diver's
  /// list; a record of the diver's being corrected or edited has no use for one.
  private var commonsOffer: CommonsOffer? {
    if model.isReopened { return nil }
    if isPushed {
      return CommonsOffer(
        label: { _ in "Save to your sites" },
        take: { savedFromSearch = model.saveToList($0) })
    }
    return onCommonsSite.map { onCommonsSite in
      CommonsOffer(
        label: { "Use \($0.name)" },
        take: { site in
          onCommonsSite(site)
          dismiss()
        })
    }
  }

  /// The boxes' position, and the geocoder asked what is there.
  private func nameEnteredPosition() async {
    await lookup.lookUp(
      session: session, latitude: model.values.latitude, longitude: model.values.longitude,
      current: { (model.values.latitude, model.values.longitude, model.values.location) },
      apply: { model.values.location = $0 })
  }

  /// What the picker settled on fills the position and the Location wholesale, and is answered
  /// before the boxes change so the change asks nothing. A pin used before its name came back is
  /// left unanswered, so the change asks for it here.
  private func use(_ picked: PickedLocation) {
    if !picked.awaitsName {
      lookup.adopt(latitude: picked.latitude, longitude: picked.longitude, credit: picked.credit)
    }
    model.values.latitude = picked.latitude
    model.values.longitude = picked.longitude
    model.values.location = picked.location
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

#Preview("Pushed") {
  NavigationStack { DiveSiteFormView(mode: .create) }
    .environment(Session.stub(transport: StubTransport(routes: [:])))
}
