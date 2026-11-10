import OpenDivingKit
import SwiftUI

/// The web's *New Dive Site* dialog: queues the site and hands back its ref, or reopens a queued
/// create the server refused (`failedItem`) and queues it again. Its location picker can hand
/// back a Commons record instead, and nothing is made.
struct NewDiveSiteSheet: View {
  let failedItem: UUID?
  /// Where the site finder was pressed, which the new site opens pinned to.
  var pin: DeviceLocation?
  /// Nil where a Commons record has nothing to go on.
  var onCommonsSite: ((DiveSiteLookupItem) -> Void)?
  var handBack: SiteProposalHandBack
  let onCreated: (RecordRef) -> Void

  @Environment(Session.self) private var session

  init(
    failedItem: UUID? = nil, pin: DeviceLocation? = nil,
    onCommonsSite: ((DiveSiteLookupItem) -> Void)? = nil,
    handBack: SiteProposalHandBack = SiteProposalHandBack(),
    onCreated: @escaping (RecordRef) -> Void
  ) {
    self.failedItem = failedItem
    self.pin = pin
    self.onCommonsSite = onCommonsSite
    self.handBack = handBack
    self.onCreated = onCreated
  }

  var body: some View {
    DiveSiteSheetForm(
      model: RecordSheetModel(
        outbox: OutboxModel(session: session), values: DiveSiteFormValues(pinnedAt: pin),
        failedItem: failedItem),
      lookup: PositionLookup(pinnedAt: pin),
      units: RecordEntryUnits(session: session), map: MapStyleModel(session: session),
      session: session, offersChoice: failedItem == nil, handBack: handBack,
      onCommonsSite: onCommonsSite, onCreated: onCreated)
  }
}

/// What a host holding a new site by its ref is told while the propose flow runs over the sheet.
struct SiteProposalHandBack {
  /// The site is saved and public was chosen: the host takes it now, and the sheet stays up.
  var onPlaced: (RecordRef) -> Void = { _ in }
  /// A Replace in the flow: the record takes the place of the site, under whichever of these
  /// refs the host holds it by.
  var onReplaced: (Set<RecordRef>, DiveSiteRead) -> Void = { _, _ in }
}

/// The dive site form as a screen of its own: the profile's new site or one pinned on the sites
/// map, a site's edit from its panel, a queued edit the server refused, or the propose flow's *Edit*. A Commons record opens its own
/// form, and one off the diver's list none.
struct DiveSiteFormView: View {
  let mode: RecordFormMode<DiveSiteRead>
  /// A new site's pin, where the site finder was pressed.
  var pin: DeviceLocation?
  /// The site was deleted from the form, which leaves the panel it was opened from nothing to show.
  var onDeleted: () -> Void = {}
  /// The site became a Commons record in the propose flow, and its panel gives way to the record's.
  var onReplaced: (UUID) -> Void = { _ in }
  /// Opened from the propose flow: no choice and no delete, and a save goes back to the flow once
  /// it has landed, or has not.
  var onLanded: ((DiveSiteLanding) -> Void)?

  @Environment(Session.self) private var session

  var body: some View {
    switch mode {
    case .create:
      form(
        RecordSheetModel(
          outbox: OutboxModel(session: session), values: DiveSiteFormValues(pinnedAt: pin)),
        lookup: PositionLookup(pinnedAt: pin))
    case .edit(let site):
      editing(site, failedItem: nil)
    case .failed(let item, let uuid):
      RecordFormLoader {
        try await session.requireClient().diveSite(uuid)
      } content: { site in
        // Through the alias the read names the record the site became.
        if site.uuid == uuid {
          editing(site, failedItem: item)
        } else {
          EmptyOrErrorView(
            status: .empty(
              icon: .diveSite, title: "Replaced",
              message: DiveSiteProposalSummary.replacedMessage))
        }
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
        offersChange: failedItem == nil, onDeleted: onDeleted)
    } else {
      form(edit(site, failedItem: failedItem), site: site, offersChoice: failedItem == nil)
    }
  }

  private func edit(_ site: DiveSiteRead, failedItem: UUID?) -> RecordSheetModel<DiveSiteFormValues>
  {
    RecordSheetModel(
      outbox: OutboxModel(session: session), editing: .server(site.uuid),
      read: DiveSiteFormValues(editing: site), failedItem: failedItem)
  }

  private func form(
    _ model: RecordSheetModel<DiveSiteFormValues>, site: DiveSiteRead? = nil,
    offersChoice: Bool = true, lookup: PositionLookup = PositionLookup()
  ) -> some View {
    DiveSiteSheetForm(
      model: model, lookup: lookup, units: RecordEntryUnits(session: session),
      map: MapStyleModel(session: session), session: session, isPushed: true, site: site,
      offersChoice: offersChoice && onLanded == nil, onLanded: onLanded,
      onCreated: { _ in }, onDeleted: onDeleted, onReplaced: onReplaced)
  }
}

private struct DiveSiteSheetForm: View {
  @State var model: RecordSheetModel<DiveSiteFormValues>
  @State var lookup: PositionLookup
  @State var units: RecordEntryUnits
  @State var map: MapStyleModel
  let session: Session
  var isPushed = false
  /// The site as the server read it, on an edit.
  var site: DiveSiteRead?
  var offersChoice = true
  var handBack = SiteProposalHandBack()
  var onLanded: ((DiveSiteLanding) -> Void)?
  var onCommonsSite: ((DiveSiteLookupItem) -> Void)?
  let onCreated: (RecordRef) -> Void
  var onDeleted: () -> Void = {}
  var onReplaced: (UUID) -> Void = { _ in }

  @State private var visibility = DiveSiteProposalSummary.Visibility.private
  /// What the save named, once it has queued and the form is staying for it.
  @State private var saved: RecordRef?
  @State private var isLanding = false
  /// The server's uuid for the site, once the save has landed.
  @State private var landed: UUID?
  /// The site the propose flow is open on.
  @State private var proposing: DiveSiteRead?
  @State private var ending: ProposeSiteFlowView.Ending?
  /// The save did not land, under this ref: the sentence, and then the form goes.
  @State private var kept: RecordRef?
  @State private var invalid: Set<String> = []
  @State private var searching = false
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
        SiteRegistriesSection(entries: $model.values.externalIds)
        SiteDepthSection(
          values: $model.values, units: units, invalid: $invalid,
          message: { model.message($0) })
        SiteEntryTypesSection(values: $model.values)
        SiteNotesSection(model: model)
        visibilitySection
      }
      .followsAddedTags(
        count: model.values.tags.count, id: SiteNotesSection.tagsField, proxy: proxy)
    }
    .disabled(isLanding)
    .overlay {
      if isLanding { BubbleSpinner() }
    }
    .navigationBarBackButtonHidden(isLanding)
    .interactiveDismissDisabled(isLanding)
    .showsMapStyle(map)
    .task { await session.loadServerInfo() }
    .task(id: isLanding) {
      guard isLanding, let saved else { return }
      let landing = await model.landing(of: saved)
      isLanding = false
      settle(landing)
    }
    .sheet(item: $proposing, onDismiss: endFlow) { site in
      ProposeSiteFlowView(
        model: DiveSiteProposalFlow(session: session, site: site), ending: $ending)
    }
    .alert(
      DiveSiteProposalSummary.keptTitle,
      isPresented: Binding(get: { kept != nil }, set: { if !$0 { kept = nil } }),
      presenting: kept
    ) { ref in
      Button("OK") { finish(ref) }
    } message: { _ in
      Text(DiveSiteProposalSummary.keptOnThePhone)
    }
    .onChange(of: position) {
      lookup.positionChanged(latitude: model.values.latitude, longitude: model.values.longitude)
    }
    .task(id: lookup.request) {
      guard lookup.request != nil else { return }
      try? await Task.sleep(for: PlaceSearch.debounce)
      guard !Task.isCancelled else { return }
      await nameEnteredPosition()
      // A cancelled task's request has been replaced, and the new one is still to be made.
      if !Task.isCancelled { lookup.finishRequest() }
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

  /// Private or public, on the diver's own site where the server takes proposals; public alone
  /// while a proposal waits.
  @ViewBuilder private var visibilitySection: some View {
    switch choice {
    case .open:
      Section {
        Picker(DiveSiteProposalSummary.visibilityTitle, selection: $visibility) {
          ForEach(DiveSiteProposalSummary.Visibility.allCases, id: \.self) { option in
            Text(option.label).tag(option)
          }
        }
        .pickerStyle(.inline)
        .labelsHidden()
      } header: {
        visibilityHeader
      } footer: {
        Text(DiveSiteProposalSummary.publicExplained)
      }
    case .locked:
      Section {
        Text(DiveSiteProposalSummary.Visibility.public.label)
      } header: {
        visibilityHeader
      } footer: {
        Text(DiveSiteProposalSummary.lockedExplained)
      }
    case nil:
      EmptyView()
    }
  }

  private var visibilityHeader: some View {
    FormSectionHeader(title: DiveSiteProposalSummary.visibilityTitle, icon: .landmark)
  }

  private var choice: DiveSiteProposalSummary.Choice? {
    guard offersChoice else { return nil }
    return DiveSiteProposalSummary.choice(site, isPrimary: session.isCommonsPrimary)
  }

  private var position: DeviceLocation? {
    PlaceSearch.position(latitude: model.values.latitude, longitude: model.values.longitude)
  }

  private var pins: [MapPoint] {
    position.map {
      [MapPoint(name: "The dive site", latitude: $0.latitude, longitude: $0.longitude)]
    } ?? []
  }

  /// From a dive's picker the record goes on the dive, and from the profile or the sites map on
  /// the diver's list; a record of the diver's being corrected or edited has no use for one.
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
  /// asked for here, the picker's answer going with it, and the position may not have changed.
  private func use(_ picked: PickedLocation) {
    if picked.awaitsName {
      lookup.ask()
    } else {
      lookup.adopt(latitude: picked.latitude, longitude: picked.longitude, credit: picked.credit)
    }
    model.values.latitude = picked.latitude
    model.values.longitude = picked.longitude
    model.values.location = picked.location
  }

  /// Queues the write. Public chosen, or a form the flow opened, stays for it to land: the
  /// proposal is sent over the server's record, and the intent is not queued.
  private func save() -> Bool {
    guard invalid.isEmpty, let ref = model.save() else { return false }
    if onLanded == nil {
      guard choice == .open, visibility == .public else {
        onCreated(ref)
        return true
      }
      handBack.onPlaced(ref)
    }
    saved = ref
    isLanding = true
    return false
  }

  private func settle(_ landing: DiveSiteLanding) {
    if let onLanded {
      onLanded(landing)
      return
    }
    switch landing {
    case .landed(let site) where site.isCommons || site.isWaitingForReview:
      finish(.server(site.uuid))
    case .landed(let site):
      landed = site.uuid
      proposing = site
    case .kept(let ref):
      kept = ref
    }
  }

  /// The flow has gone. Whatever it came to, the form is done, and the host closes with the site
  /// under the ref it now goes by.
  private func endFlow() {
    let flowed = ending
    ending = nil
    switch flowed {
    case .replaced(let retired, let record):
      var refs: Set<RecordRef> = [.server(retired)]
      if let saved { refs.insert(saved) }
      handBack.onReplaced(refs, record)
      finish(.server(record.uuid))
      onReplaced(record.uuid)
    case .kept(let ref):
      kept = ref
    case nil:
      if let landed { finish(.server(landed)) }
    }
  }

  private func finish(_ ref: RecordRef) {
    onCreated(ref)
    dismiss()
  }

  private var deletion: RecordDeletion? {
    guard model.canDelete, onLanded == nil else { return nil }
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
