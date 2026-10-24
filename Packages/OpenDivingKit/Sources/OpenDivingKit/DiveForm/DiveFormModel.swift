import Foundation
import Observation

/// The dive form as one screen holds it: the values, which fields show, the units each is typed
/// in, and what each button does with them — over the account's outbox and lookups, so it logs
/// and edits with no signal and signed out.
///
/// **A new dive is a draft from the diver's first change**, and nothing before it: a form opened
/// and left leaves no record anywhere. Every change is written within a second and reaches the
/// server as the queue coalesces it; *Log dive* queues the log of the draft, or a plain dive
/// create where the draft never left the phone.
///
/// **An edit is a diff of the dive as the form opened on it** — the cached dive with any queued
/// edit laid over, refreshed when a fetch lands and the diver has not typed — kept as a phone-
/// local edit draft until *Save changes* queues it.
///
/// **A failed item reopens here** over its own payload, with the server's sentence, and saving
/// re-queues it.
@MainActor
@Observable
public final class DiveFormModel: AccountStoresObserver {
  public enum Mode: Hashable, Sendable {
    case create
    /// A dive draft, the server's or the phone's own.
    case draft(RecordRef)
    /// A dive the account has.
    case edit(UUID)
    /// A queued dive create or update the server refused, by its outbox item.
    case failed(UUID)
  }

  public enum Phase: Hashable, Sendable {
    case loading
    case ready
    /// There is nothing to open, and the sentence says why.
    case unavailable(String)
  }

  public let mode: Mode
  public private(set) var phase: Phase = .loading
  public internal(set) var values = DiveFormValues()
  public internal(set) var visibility: DiveFormVisibility
  /// The account's units, which every value is shown in unless the diver types a dimension in
  /// the other system on this phone.
  public let units: UnitSystem
  public private(set) var entryUnits: EntryUnits
  /// Which rules a save checks: a new dive's, or an edit's.
  public private(set) var purpose: DiveFormPurpose
  /// The gear set loaded as a checklist, with what is ticked on it.
  public internal(set) var checklist: GearChecklist?
  public var isChecklistOpen = false
  /// A save was tried, so the form says what is wrong under each field from now on.
  public private(set) var attempted = false
  /// The server's sentence over a failed item, verbatim.
  public private(set) var serverSentence: String?
  /// Why the last change or save could not be kept.
  public private(set) var saveError: String?
  /// What the server suggested for the number, for the note when another dive carries it.
  public private(set) var numberSuggestion: DiveNumberSuggestion?
  /// The dive draft the form writes to, once there is one.
  public private(set) var draft: RecordRef?
  /// The form's work is queued, or its draft discarded: the screen closes.
  public private(set) var isDone = false
  /// The dive an edit compares against.
  public private(set) var baseline: DiveReadWithMixtures?
  /// An edit kept on the phone from an earlier visit, which *Discard changes* drops.
  public private(set) var hasEditDraft = false
  /// What the form names from outside the lookups: a picked search result, the edited dive's
  /// own records, a resolved species.
  private(set) var knownRows: [RecordRef: FormPickerRow] = [:]
  private(set) var knownGear: [RecordRef: GearItemInfo] = [:]
  private(set) var knownSpecies: [UUID: String] = [:]

  public let outbox: OutboxModel
  public let lookups: LookupsModel

  @ObservationIgnored let session: Session
  @ObservationIgnored private let hiddenKeys: [String]
  @ObservationIgnored private let now: Date
  @ObservationIgnored private let timeZone: TimeZone
  @ObservationIgnored private var typed = false
  @ObservationIgnored private var numberChosen = false
  @ObservationIgnored private var dirty = false
  @ObservationIgnored private var saveTask: Task<Void, Never>?
  @ObservationIgnored private var numberTask: Task<Void, Never>?
  @ObservationIgnored private var tasks: [Task<Void, Never>] = []
  @ObservationIgnored private var detail: DiveDetailModel?

  /// `now` and `timeZone` are a new dive's start; `quietInterval` is how long a draft's changes
  /// wait for the next before they are sent.
  public init(
    session: Session, mode: Mode, now: Date = Date(), timeZone: TimeZone = .current,
    quietInterval: Duration = .seconds(10)
  ) {
    self.session = session
    self.mode = mode
    self.now = now
    self.timeZone = timeZone
    outbox = OutboxModel(session: session, quietInterval: quietInterval)
    lookups = LookupsModel(session: session)
    let settings = Self.formSettings(session, account: outbox.account)
    units = settings?.units ?? .metric
    hiddenKeys = settings?.diveFormHiddenFields ?? []
    visibility = DiveFormVisibility(hiddenKeys: hiddenKeys)
    entryUnits = Self.entryUnitsStore(session, account: outbox.account)?.load() ?? EntryUnits()
    if case .edit = mode { purpose = .edit } else { purpose = .create }
  }

  /// The units and hidden fields the form honours: the account's as `GET /user` read them, or
  /// as the phone kept them when it last could — signed out, or before the account loads.
  static func formSettings(_ session: Session, account: UUID?) -> AccountFormSettings? {
    if let user = session.user {
      return AccountFormSettings(units: user.units, diveFormHiddenFields: user.diveFormHiddenFields)
    }
    guard let origin = session.state.origin, let account else { return nil }
    return session.store.formSettings(for: origin, account: account)
  }

  static func entryUnitsStore(_ session: Session, account: UUID?) -> EntryUnitsStore? {
    guard let origin = session.state.origin, let account else { return nil }
    return EntryUnitsStore(store: session.store, origin: origin, account: account)
  }

  // MARK: - What the screen shows

  /// The page's heading, the web's.
  public var title: String {
    guard purpose == .edit else { return "Log New Dive" }
    guard let number = baseline?.diveNumber else { return "Edit Dive" }
    return "Edit Dive #\(number)"
  }

  /// The save button's label, the web's.
  public var submitLabel: String { purpose == .edit ? "Save changes" : "Log dive" }

  /// The sections the form renders, in the web's order: *Dive info* always, any other while one
  /// of its fields is shown.
  public var sections: [DiveFormGroup] {
    DiveFormGroup.allCases.filter { $0.isShown(visibility, values: values) }
  }

  public func shows(_ field: DiveFormField) -> Bool { visibility.shows(field, in: values) }

  /// Whether a new dive's required fields are marked.
  public var marksRequired: Bool { purpose == .create }

  /// Every sentence the values earn, once a save has been tried.
  public var issues: [FormIssue] { attempted ? values.issues(for: purpose) : [] }

  /// The sentence under one field, or one member of one row.
  public func message(_ field: String, index: Int? = nil, member: String? = nil) -> String? {
    FormInvalid(issues: issues).message(for: field, index: index, member: member)
  }

  /// The web's note under the number while it holds a suggestion another dive carries.
  public var numberNotice: String? {
    guard let numberSuggestion, values.diveNumber == numberSuggestion.diveNumber else {
      return nil
    }
    return DiveNumberRule.takenNotice(numberSuggestion)
  }

  /// The offsets the start's menu offers: *Not recorded* only while the dive being edited has
  /// none.
  public var offsetChoices: [Int?] { DiveStart.offsetChoices(editing: baseline) }

  /// The drafts *Log a dive* offers before a new form is touched.
  public var draftRows: [DiveDraftRowContent] {
    DiveDraftRowContent.rows(outbox.drafts, sites: lookups.diveSites, timeZone: timeZone)
  }

  /// Whether the form can ask the server: signed in, with a route believed to exist. It decides
  /// only whether a suggestion or a search is asked for — nothing is refused on it.
  public var isOnline: Bool {
    guard case .signedIn = session.state, session.client != nil else { return false }
    return session.connectivity.isRouteAvailable
  }

  // MARK: - Units

  /// The system `measure` is typed in on this phone.
  public func entryUnits(_ measure: Measure) -> UnitSystem {
    entryUnits.units(measure, account: units)
  }

  /// The toggle beside a measured field, kept for this phone and never sent.
  public func toggleEntryUnits(_ measure: Measure) {
    entryUnits.toggle(measure, account: units)
    try? Self.entryUnitsStore(session, account: outbox.account)?.save(entryUnits)
  }

  /// A field's label with the unit it is typed in: `Maximum depth (ft)`.
  public func label(_ label: String, _ measure: Measure) -> String {
    "\(label) (\(measure.label(entryUnits(measure))))"
  }

  /// A stored metric value as its box shows it in the entry units.
  public func entryText(_ metric: Double?, _ measure: Measure) -> String {
    guard let metric else { return "" }
    return UnitFormat.number(metric, measure, entryUnits(measure))
  }

  /// What a typed number stores: metric, rounded as the web commits it, whole for the integer
  /// dimensions; nil for an empty box or one that is not a number.
  public func metric(fromEntry text: String, _ measure: Measure) -> Double? {
    guard var typed = DecimalEntry.parse(text) else { return nil }
    if measure.metricDecimals == 0 { typed.round(.towardZero) }
    return measure.fromDisplay(typed, entryUnits(measure))
  }

  /// `e.g. 100` for a metric example shown in feet.
  public func placeholder(_ metricExample: Double, _ measure: Measure) -> String {
    let shown = entryUnits(measure)
    return "e.g. "
      + (shown == .imperial
        ? UnitFormat.number(metricExample, measure, shown) : NumberText.plain(metricExample))
  }

  /// What is wrong with a typed number for a field bounded, in metric, by `min` and `max`.
  public func entryMessage(_ text: String, _ measure: Measure, min: Double?, max: Double?)
    -> String?
  {
    let shown = entryUnits(measure)
    return DecimalEntry.message(
      text, min: min.map { measure.displayBound($0, shown, isMinimum: true) },
      max: max.map { measure.displayBound($0, shown, isMinimum: false) })
  }

  // MARK: - Opening

  /// Opens the form on what its mode names. A new form's start, number and carried fields are
  /// its own and no change of the diver's.
  public func start() async {
    guard phase == .loading else { return }
    if let stores = AccountStores.current(session) {
      OutboxHub.hub(for: stores.directory).observe(self)
    }
    // The pickers' tables and the drafts as the server holds them, when it can be asked: with
    // no route the cached ones stand, and a route appearing refreshes them anyway.
    if isOnline { track(Task { await lookups.refresh() }) }
    switch mode {
    case .create: startCreate()
    case .draft(let ref): startDraft(ref)
    case .edit(let uuid): startEdit(uuid)
    case .failed(let id): startFailed(id)
    }
  }

  private func startCreate() {
    let number = offlineNumber
    if let last = cachedLastDive() {
      values = .carried(
        from: last, number: number, visibility: visibility, now: now, timeZone: timeZone)
      remember(last)
    } else {
      values = visibility.applied(to: .newDive(number: number, now: now, timeZone: timeZone))
    }
    attachVessels()
    phase = .ready
    suggestNumber()
    if isOnline { track(Task { await outbox.refreshDrafts() }) }
  }

  private func startDraft(_ ref: RecordRef) {
    guard let entry = outbox.drafts.first(where: { $0.ref == ref }) else {
      phase = .unavailable(Self.draftGone)
      return
    }
    draft = entry.ref
    values = DiveFormValues(draft: entry.write.values)
    visibility.reveal(holdingValuesIn: values)
    if let set = entry.write.gearSet { checklist = rebuiltChecklist(set) }
    attachVessels()
    phase = .ready
    if values.diveNumber == nil {
      values.diveNumber = offlineNumber
      suggestNumber()
    }
  }

  private func startEdit(_ uuid: UUID) {
    if let saved = DraftStore<DiveEditDraft>(session: session)?.load(.server(uuid)) {
      open(saved.baseline, values: saved.values)
      typed = true
      hasEditDraft = true
    } else if let cached = outbox.cachedDive(uuid) {
      open(cached)
    }
    let detail = DiveDetailModel(session: session, diveUUID: uuid)
    self.detail = detail
    track(
      Task {
        await detail.load()
        if let dive = detail.dive {
          if !typed { open(dive) }
        } else if phase == .loading, case .failed(let error) = detail.phase {
          phase = .unavailable(error.message)
        }
      })
  }

  private func startFailed(_ id: UUID) {
    guard let item = outbox.item(id) else {
      phase = .unavailable(Self.itemGone)
      return
    }
    serverSentence = item.failure?.message ?? item.lastAnswer?.sentence
    switch item.operation {
    case .createDive(let dive), .logDive(_, let dive):
      values = DiveFormValues(create: dive)
      visibility.reveal(holdingValuesIn: values)
      attachVessels()
      phase = .ready
    case .updateDive(let ref, _):
      // The dive as the server last sent it is what the update is a diff of; the form shows
      // it with every queued edit laid over, the refused one included.
      guard let uuid = ref.serverUUID, let shown = outbox.cachedDive(uuid),
        let stores = AccountStores.current(session),
        let read = stores.cache.dive(uuid)?.value.dive
      else {
        phase = .unavailable(Self.diveNotHere)
        return
      }
      purpose = .edit
      open(read, values: DiveFormValues(editing: shown))
    default:
      phase = .unavailable(Self.itemGone)
    }
  }

  private func open(_ dive: DiveReadWithMixtures, values: DiveFormValues? = nil) {
    baseline = dive
    self.values = values ?? DiveFormValues(editing: dive)
    visibility = DiveFormVisibility(hiddenKeys: hiddenKeys)
    visibility.reveal(holdingValuesIn: self.values)
    remember(dive)
    attachVessels()
    phase = .ready
  }

  /// The newest dive of the first page the phone has shown, as its cache holds it: what a new
  /// dive carries from. Nothing is fetched for it.
  private func cachedLastDive() -> DiveReadWithMixtures? {
    guard let stores = AccountStores.current(session),
      let first = stores.cache.pages(PageCacheKey.dives.name, of: DiveListItem.self)?.value.items
        .first
    else { return nil }
    return outbox.cachedDive(first.id)
  }

  /// The number offered offline: one above the newest-dated dive the phone has seen, plus the
  /// dives queued since.
  private var offlineNumber: Int? {
    DiveNumberRule.offlineSuggestion(
      highestKnown: outbox.highestKnownDiveNumber, queuedCreates: outbox.queuedDiveCreates)
  }

  /// Asks the server for the number a dive starting then takes, while the diver has not chosen
  /// one; the answer replaces the offline guess.
  private func suggestNumber() {
    numberTask?.cancel()
    guard !numberChosen, isOnline, let client = session.client,
      let start = values.startTime, case .instant = start
    else { return }
    let task = Task {
      guard let answer = try? await client.nextDiveNumber(startTime: start), !Task.isCancelled,
        !numberChosen, values.startTime == start
      else { return }
      numberSuggestion = answer
      if values.diveNumber != answer.diveNumber {
        values.diveNumber = answer.diveNumber
        if draft != nil { persistSoon() }
      }
    }
    numberTask = task
    track(task)
  }

  // MARK: - Changing

  /// The diver's change to the values. The first one in a new form begins its draft.
  public func change(_ body: (inout DiveFormValues) -> Void) {
    var next = values
    body(&next)
    guard next != values, !isDone else { return }
    if next.diveNumber != values.diveNumber { numberChosen = true }
    let startChanged = next.startTime != values.startTime
    values = next
    typed = true
    persistSoon()
    if startChanged { suggestNumber() }
  }

  private func persistSoon() {
    dirty = true
    saveTask?.cancel()
    saveTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(400))
      guard !Task.isCancelled else { return }
      self?.persist()
    }
  }

  /// Writes what changed: the draft through the queue, or the edit to the phone's edit drafts.
  private func persist() {
    guard dirty, !isDone else { return }
    dirty = false
    switch mode {
    case .create, .draft:
      let write = values.draft(gearSet: checklist?.set)
      do {
        if let draft {
          try outbox.saveDraft(draft, write)
        } else {
          draft = try outbox.beginDraft(write)
        }
        saveError = nil
      } catch {
        saveError = Self.noStores
      }
    case .edit(let uuid):
      guard let baseline, let store = DraftStore<DiveEditDraft>(session: session) else { return }
      do {
        try store.save(DiveEditDraft(baseline: baseline, values: values), for: .server(uuid))
        hasEditDraft = true
        saveError = nil
      } catch {
        saveError = Self.notKept
      }
    case .failed:
      break
    }
  }

  /// The form was left: what it holds is written now, and a draft's changes go to the server.
  public func leave() {
    saveTask?.cancel()
    persist()
    numberTask?.cancel()
    if draft != nil { outbox.leaveDraft() }
  }

  // MARK: - Saving

  /// *Log dive* or *Save changes*: checks the values as the web does, and queues them. False,
  /// with the sentences on the fields, when they do not pass.
  @discardableResult
  public func submit() -> Bool {
    attempted = true
    guard phase == .ready, !isDone else { return false }
    let wasDirty = dirty
    saveTask?.cancel()
    dirty = false
    do {
      switch mode {
      case .create, .draft: try logDive()
      case .edit(let uuid): try saveEdit(uuid)
      case .failed(let id):
        if purpose == .edit { try resubmitUpdate(id) } else { try resubmitCreate(id) }
      }
      saveError = nil
      isDone = true
      return true
    } catch let invalid as FormInvalid {
      visibility.reveal(failing: invalid)
    } catch OutboxModel.OutboxError.notEditable {
      saveError = Self.notEditable
    } catch {
      saveError = Self.noStores
    }
    if wasDirty { persistSoon() }
    return false
  }

  private func logDive() throws {
    let dive = try values.toCreate()
    if let draft {
      try outbox.logDraft(draft, dive)
    } else {
      try outbox.queue(.createDive(dive))
    }
  }

  private func saveEdit(_ uuid: UUID) throws {
    guard let baseline else { throw FormInvalid(issues: []) }
    let update = try values.diff(from: baseline)
    if !update.isEmpty { try outbox.queue(.updateDive(.server(uuid), update)) }
    DraftStore<DiveEditDraft>(session: session)?.remove(.server(uuid))
  }

  private func resubmitCreate(_ id: UUID) throws {
    let dive = try values.toCreate()
    guard let item = outbox.item(id) else { throw OutboxModel.OutboxError.notEditable }
    if case .logDive(let draft, _) = item.operation {
      try outbox.edit(id, .logDive(fromDraft: draft, dive))
    } else {
      try outbox.edit(id, .createDive(dive))
    }
  }

  private func resubmitUpdate(_ id: UUID) throws {
    guard let baseline, let item = outbox.item(id),
      case .updateDive(let ref, _) = item.operation
    else { throw OutboxModel.OutboxError.notEditable }
    let update = try values.diff(from: baseline)
    if update.isEmpty {
      outbox.discard(id)
    } else {
      try outbox.edit(id, .updateDive(ref, update))
    }
  }

  /// *Discard draft*, after the confirmation: the draft goes on every device.
  public func discardDraft() {
    saveTask?.cancel()
    dirty = false
    guard let draft else {
      isDone = true
      return
    }
    do {
      try outbox.discardDraft(draft)
      isDone = true
    } catch {
      saveError = Self.noStores
    }
  }

  /// *Discard changes* on an edit kept from an earlier visit: the form opens on the dive again.
  public func discardEdit() {
    guard case .edit(let uuid) = mode else { return }
    saveTask?.cancel()
    dirty = false
    DraftStore<DiveEditDraft>(session: session)?.remove(.server(uuid))
    hasEditDraft = false
    typed = false
    attempted = false
    if let dive = detail?.dive ?? outbox.cachedDive(uuid) { open(dive) }
  }

  // MARK: - The queue's changes

  /// A record the form names landed, or was discarded: the form names it as the queue now does
  /// — by the server's uuid, or not at all.
  func accountStoresChanged() {
    guard let stores = AccountStores.current(session) else { return }
    let resolutions = stores.outbox.resolutions()
    let creating = Set(stores.outbox.items().compactMap(\.creates))
    func rewrite(_ ref: RecordRef) -> RecordRef? {
      guard case .local(let local) = ref else { return ref }
      if let resolution = resolutions[local] {
        return resolution.server.map(RecordRef.server) ?? ref
      }
      return creating.contains(ref) ? ref : nil
    }
    var next = values
    next.rewriteRefs(rewrite)
    if next != values { values = next }
    if var list = checklist {
      list.rewriteRefs(rewrite)
      if list != checklist { checklist = list }
    }
    if let draft, case .local = draft, let server = rewrite(draft), server != draft {
      self.draft = server
    }
  }

  // MARK: - Waiting, for tests

  /// Waits for what opening and changing the form started: the fetches, the draft's write and
  /// the queue's flush.
  public func settled() async {
    while !tasks.isEmpty {
      let running = tasks
      tasks = []
      for task in running { await task.value }
    }
    if let saveTask { await saveTask.value }
    await outbox.settled()
  }

  private func track(_ task: Task<Void, Never>) {
    tasks.append(task)
  }

  // MARK: - Names

  /// Remembers what a dive names, for the labels of an edit.
  private func remember(_ dive: DiveReadWithMixtures) {
    for site in dive.diveSites {
      knownRows[site.ref] = FormPickerRow(ref: site.ref, title: site.name)
    }
    for item in dive.gearItems { knownGear[item.ref] = item }
    for mixture in dive.mixtures {
      if let item = mixture.gearItem { knownGear[item.ref] = item }
    }
    for sighting in dive.sightings {
      knownSpecies[sighting.uuid] = SpeciesNames.displayName(
        scientificName: sighting.scientificName, commonName: sighting.commonName)
    }
  }

  func remember(_ rows: [FormPickerRow]) {
    for row in rows where knownRows[row.ref] == nil { knownRows[row.ref] = row }
  }

  func remember(gear items: [GearItemInfo]) {
    for item in items { knownGear[item.ref] = item }
  }

  func remember(species uuid: UUID, name: String) {
    knownSpecies[uuid] = name
  }

  // MARK: - Sentences

  /// The web's, for a draft logged or discarded elsewhere.
  static let draftGone =
    "This draft is no longer here - it was logged or discarded, perhaps on another device."
  static let itemGone = "This dive is no longer waiting to be saved."
  static let diveNotHere = "This dive is not on the phone. Open it once with a connection first."
  static let noStores =
    "This dive cannot be kept yet: the app has not loaded your account. Try again once it has reached your server."
  static let notKept = "Your changes could not be kept on the phone."
  static let notEditable = "This dive is being sent now. Try again once it has been answered."
}
