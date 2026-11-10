import OpenDivingKit
import SwiftUI

/// Everything the phone holds that the server does not have yet, item by item, with what the
/// server last said about each and the way out of each: the drafts, the writes waiting, what
/// this build cannot read, what is done but said once, and the files waiting to import, each
/// with where it stands.
///
/// Signed in it ends in *Sync now*, which leaves the files to *Upload* on the Import screen. Signed
/// out — a sheet off the email screen, over the stores of the account last loaded here — it says
/// that signing in syncs.
struct PendingScreen: View {
  @Environment(Session.self) private var session
  @Environment(OutboxModel.self) private var outbox
  @Environment(InboxModel.self) private var inbox

  @State private var route: PendingRoute?
  @State private var sheet: PendingSheet?
  @State private var discarding: OutboxItem?
  @State private var discardingUnreadable: String?

  private var signedIn: Bool {
    if case .signedIn = session.state { true } else { false }
  }

  private var isEmpty: Bool {
    outbox.drafts.isEmpty && outbox.items.isEmpty && outbox.unreadable.isEmpty
      && outbox.notices.isEmpty && inbox.files.isEmpty
  }

  private var isSyncing: Bool { outbox.isFlushing }

  var body: some View {
    List {
      if !signedIn {
        Section {
        } footer: {
          VStack(alignment: .leading, spacing: 4) {
            Text(PendingText.signInToSync).font(.footnote.weight(.semibold))
            Text(PendingText.signInToSyncDetail)
          }
        }
      }
      if isEmpty {
        Section {
          Text("Nothing is waiting. Everything on this phone has reached the server.")
            .foregroundStyle(.secondary)
        }
      }
      drafts
      waiting
      unreadable
      notices
      files
      if signedIn {
        Section {
          Button {
            outbox.syncNow()
          } label: {
            if isSyncing {
              HStack {
                BubbleSpinner()
                Text("Syncing…")
              }
            } else {
              Text(PendingText.syncNow)
            }
          }
          .accentRow()
          .disabled(isSyncing)
        }
      }
    }
    .navigationTitle(PendingText.title)
    .navigationDestination(item: $route) { route in
      switch route {
      case .form(let mode): DiveFormView(mode: mode)
      case .trip(let mode): TripFormView(mode: mode)
      case .diveSite(let mode): DiveSiteFormView(mode: mode)
      case .person(let mode): PersonFormView(mode: mode)
      case .course(let mode): CourseFormView(mode: mode)
      case .contact(let mode): ContactFormView(mode: mode)
      case .gearItem(let mode): GearItemFormView(mode: mode)
      case .certification(let mode, let failedItem):
        CertificationFormView(mode: mode, failedItem: failedItem)
      case .serviceSchedule(let gearItem, let mode, let failedItem):
        ServiceScheduleFormView(gearItem: gearItem, mode: mode, failedItem: failedItem)
      case .serviceRecord(let gearItem, let mode, let failedItem):
        ServiceRecordFormView(gearItem: gearItem, mode: mode, failedItem: failedItem)
      case .importFiles: ImportView()
      }
    }
    .sheet(item: $sheet) { sheet in
      recordSheet(sheet)
    }
    .confirmationDialog(
      discarding.map { "Discard \(title(of: $0))?" } ?? "",
      isPresented: Binding(get: { discarding != nil }, set: { if !$0 { discarding = nil } }),
      titleVisibility: .visible, presenting: discarding
    ) { item in
      Button("Discard", role: .destructive) { outbox.discard(item.id) }
    } message: { item in
      Text(discardMessage(item))
    }
    .confirmationDialog(
      "Discard what another version of the app saved?",
      isPresented: Binding(
        get: { discardingUnreadable != nil }, set: { if !$0 { discardingUnreadable = nil } }),
      titleVisibility: .visible, presenting: discardingUnreadable
    ) { name in
      Button("Discard", role: .destructive) { outbox.discardUnreadable(name) }
    } message: { _ in
      Text(PendingText.unreadableDiscard)
    }
    // Whenever the drafts are shown; the outbox refreshes nothing before the account loads.
    .task { await outbox.refreshDrafts() }
  }

  // MARK: - Sections

  @ViewBuilder private var drafts: some View {
    if !outbox.drafts.isEmpty {
      Section("Drafts") {
        ForEach(outbox.drafts) { entry in
          Button {
            route = .form(.draft(entry.ref))
          } label: {
            VStack(alignment: .leading, spacing: 2) {
              Text(PendingText.draftTitle(entry.write))
              Text(PendingText.draftChanged(entry))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .foregroundStyle(.primary)
        }
      }
    }
  }

  @ViewBuilder private var waiting: some View {
    if !outbox.items.isEmpty {
      Section("Waiting to Sync") {
        ForEach(outbox.items) { item in
          PendingItemRow(
            item: item, title: title(of: item),
            heldBehind: outbox.heldBehind(item).map { title(of: $0) },
            edit: Self.edit(item).map { edit in { open(edit) } },
            discard: item.isDiscardable ? { discarding = item } : nil)
        }
      }
    }
  }

  @ViewBuilder private var unreadable: some View {
    if !outbox.unreadable.isEmpty {
      Section {
        ForEach(outbox.unreadable, id: \.self) { name in
          HStack {
            Text(OutboxText.unreadableItem)
            Spacer()
            Button("Discard", role: .destructive) { discardingUnreadable = name }
              .dangerRow()
              .buttonStyle(.borderless)
          }
        }
      }
    }
  }

  @ViewBuilder private var notices: some View {
    if !outbox.notices.isEmpty {
      Section {
        ForEach(outbox.notices) { notice in
          HStack(alignment: .firstTextBaseline) {
            Text(notice.sentence)
            Spacer()
            Button("Dismiss") { outbox.dismiss(notice) }
              .accentRow()
              .buttonStyle(.borderless)
          }
        }
      }
    }
  }

  @ViewBuilder private var files: some View {
    if !inbox.files.isEmpty {
      Section {
        ForEach(inbox.files) { file in
          let stage = inbox.stage(of: file)
          VStack(alignment: .leading, spacing: 2) {
            Label(ImportFileRow.title(file), systemImage: "doc")
            Text(PendingText.fileStage(stage))
              .font(.caption)
              .foregroundStyle(stage.isRefused ? Color.danger : Color.secondary)
          }
        }
        if signedIn {
          Button(PendingText.openImport, systemImage: "square.and.arrow.down") {
            route = .importFiles
          }
          .accentRow()
        }
      } header: {
        Text(PendingText.filesHeader)
      } footer: {
        if let footer = Self.filesFooter(inbox) {
          Text(footer)
        }
      }
    }
  }

  /// Beneath the files: why they cannot go as one import.
  static func filesFooter(_ inbox: InboxModel) -> String? { inbox.selectionRefusal }

  // MARK: - Editing and discarding

  private func title(of item: OutboxItem) -> String {
    PendingText.title(of: item) { outbox.cachedDive($0) }
  }

  /// What *Edit* opens on `item`, when it offers one: a dive opens the form on the item, a
  /// draft's own write the draft, and a record its sheet.
  static func edit(_ item: OutboxItem) -> PendingEdit? {
    guard item.isEditable else { return nil }
    switch item.operation {
    case .createDive, .updateDive, .logDive:
      return .form(.failed(item.id))
    case .updateDiveSite(let ref, _):
      return ref.serverUUID.map { .diveSite(.failed(item: item.id, record: $0)) }
    case .updateTrip(let ref, _):
      return ref.serverUUID.map { .trip(.failed(item: item.id, record: $0)) }
    case .updatePerson(let ref, _):
      return ref.serverUUID.map { .route(.person(.failed(item: item.id, record: $0))) }
    case .updateCourse(let ref, _):
      return ref.serverUUID.map { .route(.course(.failed(item: item.id, record: $0))) }
    case .updateContact(let ref, _):
      return ref.serverUUID.map { .route(.contact(.failed(item: item.id, record: $0))) }
    case .updateGearItem(let ref, _):
      return ref.serverUUID.map { .route(.gearItem(.failed(item: item.id, record: $0))) }
    // A refused card image reopens its certification's form, where the side is picked again.
    case .updateCertification(let ref, _), .putCertificationFile(let ref, _):
      return ref.serverUUID.map {
        .route(.certification(.failed(item: item.id, record: $0), failedItem: nil))
      }
    case .updateServiceSchedule(let ref, let gearItem, _):
      return ref.serverUUID.map {
        .route(
          .serviceSchedule(
            gearItem: gearItem, .failed(item: item.id, record: $0), failedItem: nil))
      }
    case .updateServiceRecord(let ref, let gearItem, _):
      return ref.serverUUID.map {
        .route(
          .serviceRecord(gearItem: gearItem, .failed(item: item.id, record: $0), failedItem: nil))
      }
    case .createCertification:
      return .route(.certification(.create, failedItem: item.id))
    case .createServiceSchedule(let body):
      return .route(.serviceSchedule(gearItem: body.gearItem, .create, failedItem: item.id))
    case .createServiceRecord(let body):
      return .route(.serviceRecord(gearItem: body.gearItem, .create, failedItem: item.id))
    case .deleteDive, .deleteDiveSite, .saveDiveSite, .deletePerson, .deleteTrip, .deleteCourse,
      .deleteContact, .deleteGearItem, .deleteGearSet, .deleteServiceSchedule,
      .deleteServiceRecord, .deleteCertification, .deleteCertificationFile:
      return nil
    case .createDiveDraft, .updateDiveDraft, .deleteDiveDraft:
      return (item.creates ?? item.operation.target).map { .form(.draft($0)) }
    case .createDiveSite: return .sheet(.diveSite(item.id))
    case .createPerson: return .sheet(.person(item.id))
    case .createTrip: return .sheet(.trip(item.id))
    case .createCourse: return .sheet(.course(item.id))
    case .createContact: return .sheet(.contact(item.id))
    case .createGearItem: return .sheet(.gearItem(item.id))
    case .createGearSet(let body):
      return .sheet(.gearSet(item.id, items: body.gearItems, weight: body.weight))
    case .updateGearSet(_, let body):
      let weight: Double? = if case .value(let weight) = body.weight { weight } else { nil }
      return .sheet(.gearSet(item.id, items: body.gearItems ?? [], weight: weight))
    }
  }

  private func open(_ edit: PendingEdit) {
    switch edit {
    case .form(let mode): route = .form(mode)
    case .trip(let mode): route = .trip(mode)
    case .diveSite(let mode): route = .diveSite(mode)
    case .route(let target): route = target
    case .sheet(let target): sheet = target
    }
  }

  @ViewBuilder private func recordSheet(_ sheet: PendingSheet) -> some View {
    let done: (RecordRef) -> Void = { _ in self.sheet = nil }
    switch sheet {
    case .diveSite(let id): NewDiveSiteSheet(failedItem: id, onCreated: done)
    case .person(let id): NewPersonSheet(failedItem: id, onCreated: done)
    case .trip(let id): NewTripSheet(failedItem: id, onCreated: done)
    case .course(let id): NewCourseSheet(failedItem: id, onCreated: done)
    case .contact(let id): NewContactSheet(failedItem: id, onCreated: done)
    case .gearItem(let id): NewGearItemSheet(failedItem: id, onCreated: done)
    case .gearSet(let id, let items, let weight):
      SaveGearSetSheet(items: items, weight: weight, failedItem: id, onSaved: done)
    }
  }

  private func discardMessage(_ item: OutboxItem) -> String {
    let effects = outbox.discardEffects(item.id)
    let logged = effects.withdrawn.filter {
      if case .logDive = $0.operation { true } else { false }
    }
    let withdrawn = effects.withdrawn.filter { !logged.contains($0) }
    return PendingText.discardMessage(
      released: effects.released.map(title(of:)), withdrawn: withdrawn.map(title(of:)),
      logged: logged.map(title(of:)))
  }
}

/// Where the pending screen pushes.
enum PendingRoute: Hashable {
  case form(DiveFormMode)
  case trip(RecordFormMode<TripRead>)
  case diveSite(RecordFormMode<DiveSiteRead>)
  case person(RecordFormMode<PersonRead>)
  case course(RecordFormMode<CourseRead>)
  case contact(RecordFormMode<ContactRead>)
  case gearItem(RecordFormMode<GearItemRead>)
  /// `failedItem` is a refused create to reopen, with `.create`.
  case certification(RecordFormMode<CertificationRead>, failedItem: UUID?)
  case serviceSchedule(gearItem: RecordRef, RecordFormMode<UUID>, failedItem: UUID?)
  case serviceRecord(gearItem: RecordRef, RecordFormMode<UUID>, failedItem: UUID?)
  case importFiles
}

/// What *Edit* on a queued write opens.
enum PendingEdit: Hashable {
  case form(DiveFormMode)
  case trip(RecordFormMode<TripRead>)
  case diveSite(RecordFormMode<DiveSiteRead>)
  /// One of More's record forms.
  case route(PendingRoute)
  case sheet(PendingSheet)
}

/// The record sheet an *Edit* opens on a queued create, by the item's id.
enum PendingSheet: Hashable, Identifiable {
  case diveSite(UUID)
  case person(UUID)
  case trip(UUID)
  case course(UUID)
  case contact(UUID)
  case gearItem(UUID)
  case gearSet(UUID, items: [RecordRef], weight: Double?)

  var id: UUID {
    switch self {
    case .diveSite(let id), .person(let id), .trip(let id), .course(let id), .contact(let id),
      .gearItem(let id), .gearSet(let id, _, _):
      id
    }
  }
}

/// One queued write: what it is, when it was queued, what the server last said or why it
/// failed, what it waits behind, and its *Edit* and *Discard* where it has them.
struct PendingItemRow: View {
  let item: OutboxItem
  let title: String
  let heldBehind: String?
  let edit: (() -> Void)?
  let discard: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
      Text(PendingText.queued(item.queuedAt))
        .font(.caption)
        .foregroundStyle(.secondary)
      Group {
        if item.state == .inFlight {
          Text("Sending…")
        }
        if let answer = item.lastAnswer {
          Text(answer.sentence)
        }
        if let dropped = PendingText.dropped(item) {
          Text(dropped)
        }
        if let heldBehind {
          Text(PendingText.heldBehind(heldBehind))
        }
      }
      .font(.footnote)
      .foregroundStyle(.secondary)
      if let failure = item.failure {
        Label(failure.message, systemImage: "exclamationmark.triangle")
          .font(.footnote)
          .foregroundStyle(Color.danger)
      }
      if edit != nil || discard != nil {
        HStack(spacing: 16) {
          if let edit {
            Button("Edit", action: edit)
              .accentRow()
          }
          if let discard {
            Button("Discard", role: .destructive, action: discard)
              .dangerRow()
          }
        }
        .buttonStyle(.borderless)
        .font(.subheadline)
        .padding(.top, 4)
      }
    }
    .padding(.vertical, 2)
  }
}

#Preview {
  NavigationStack {
    PendingScreen()
  }
  .environment(DivePreviewData.session)
  .environment(OutboxModel(session: DivePreviewData.session))
  .environment(InboxModel(session: DivePreviewData.session))
}
