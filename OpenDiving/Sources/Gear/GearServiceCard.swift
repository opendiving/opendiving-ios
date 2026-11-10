import OpenDivingKit
import SwiftUI

/// A gear item's service schedules, with their status, and its service history, on the item's page.
/// A schedule is added, logged against, paused, resumed, edited and deleted from here, and a
/// service logged, edited and deleted; each is queued, and its row shows once it lands.
struct GearServiceCard: View {
  let gearItem: GearItemRead
  let service: GearServiceModel

  @Environment(Session.self) private var session
  @Environment(OutboxModel.self) private var outbox
  @State private var lookups: LookupsModel?
  @State private var deleting: Deleting?
  @State private var queueError: String?

  /// The row whose delete is being confirmed.
  private enum Deleting: Identifiable {
    case schedule(UUID)
    case record(UUID)

    var id: UUID {
      switch self {
      case .schedule(let uuid), .record(let uuid): uuid
      }
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      if GearServiceCardContent.hasPendingWrite(outbox.items, gearItem: gearItem.uuid) {
        PendingEditLine()
      }
      schedules
      history
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.cardFill, in: .formSection)
    .task { if lookups == nil { lookups = LookupsModel(session: session) } }
    .confirmationDialog(
      deletingTitle, isPresented: isDeleting, titleVisibility: .visible, presenting: deleting
    ) { target in
      Button("Delete", role: .destructive) { delete(target) }
    } message: { target in
      switch target {
      case .schedule: Text(RecordDeletionText.serviceSchedule)
      case .record: Text(RecordDeletionText.serviceRecord)
      }
    }
    .alert(
      "Not saved",
      isPresented: Binding(get: { queueError != nil }, set: { if !$0 { queueError = nil } })
    ) {
      Button("OK") {}
    } message: {
      Text(queueError ?? "")
    }
  }

  private var header: some View {
    HStack(spacing: 8) {
      Image(.wrench)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      Text("Service")
        .accessibilityAddTraits(.isHeader)
      Spacer()
      NavigationLink {
        ServiceScheduleFormView(gearItem: ref, mode: .create, gearType: gearItem.type)
      } label: {
        Label("Add schedule", systemImage: "plus")
          .font(.subheadline)
      }
      .buttonStyle(.bordered)
    }
    .font(.headline)
  }

  @ViewBuilder private var schedules: some View {
    switch service.schedules.phase {
    case .idle, .loading:
      BubbleSpinner()
        .frame(maxWidth: .infinity)
    case .failed(let error):
      failed(error) { await service.schedules.load() }
    case .loaded where service.schedules.items.isEmpty:
      Text(GearServiceCardContent.noSchedules)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    case .loaded:
      ForEach(service.schedules.items) { schedule in
        scheduleRow(schedule)
      }
    }
  }

  private func scheduleRow(_ schedule: GearServiceScheduleRead) -> some View {
    let row = GearServiceCardContent.row(
      schedule, diveCount: gearItem.diveCount, diveTime: gearItem.diveTime,
      today: CalendarDate.today())
    return HStack(alignment: .top, spacing: 8) {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(row.kind).fontWeight(.medium)
          if let label = row.label {
            Text("(\(label))").foregroundStyle(.secondary)
          }
          if row.isPaused {
            BadgeView("Paused", style: .outline)
          }
        }
        if let status = row.status {
          HStack(spacing: 8) {
            BadgeView(status.text, style: status.style)
            if let due = row.due {
              Text(due).font(.caption).foregroundStyle(.secondary)
            }
          }
        } else {
          Text("—").foregroundStyle(.secondary)
        }
        Text(row.intervals)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      HStack(spacing: 2) {
        NavigationLink {
          ServiceRecordFormView(gearItem: ref, mode: .create, schedule: schedule.uuid)
        } label: {
          RowIcon(Image(.clipboardCheck), label: row.logLabel)
        }
        Button {
          queue(
            .updateServiceSchedule(
              .server(schedule.uuid), gearItem: ref,
              GearServiceScheduleUpdate(active: !schedule.isActive)))
        } label: {
          RowIcon(Image(systemName: schedule.isActive ? "pause" : "play"), label: row.toggleLabel)
        }
        NavigationLink {
          ServiceScheduleFormView(gearItem: ref, mode: .edit(schedule.uuid))
        } label: {
          RowIcon(Image(systemName: "pencil"), label: row.editLabel)
        }
        Button {
          deleting = .schedule(schedule.uuid)
        } label: {
          RowIcon(Image(systemName: "trash"), label: row.deleteLabel)
        }
      }
      .buttonStyle(.borderless)
    }
    .padding(12)
    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(.separator)))
  }

  private var history: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Service History")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)
          .accessibilityAddTraits(.isHeader)
        Spacer()
        NavigationLink {
          ServiceRecordFormView(gearItem: ref, mode: .create)
        } label: {
          Label("Log service", systemImage: "plus")
            .font(.subheadline)
        }
        .buttonStyle(.bordered)
      }
      switch service.records.phase {
      case .idle, .loading:
        BubbleSpinner()
          .frame(maxWidth: .infinity)
      case .failed(let error):
        failed(error) { await service.records.load() }
      case .loaded where service.records.items.isEmpty:
        Text(GearServiceCardContent.noRecords)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      case .loaded:
        ForEach(service.records.items) { record in
          recordRow(record)
        }
        PageEndTrigger(list: service.records)
        LoadMoreFooter(list: service.records)
      }
    }
    .padding(.top, 12)
  }

  private func recordRow(_ record: GearServiceRecordRead) -> some View {
    let row = GearServiceCardContent.row(record, contacts: lookups?.contacts ?? [])
    return HStack(alignment: .top, spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        Text(
          "\(Text(row.kind).fontWeight(.medium))\(Text(Self.after(row)).foregroundStyle(.secondary))"
        )
        if let servicedBy = row.servicedBy {
          Text(servicedBy).foregroundStyle(.secondary)
        }
        if let notes = row.notes {
          Text(notes).foregroundStyle(.secondary)
        }
      }
      .font(.subheadline)
      .frame(maxWidth: .infinity, alignment: .leading)
      HStack(spacing: 2) {
        NavigationLink {
          ServiceRecordFormView(gearItem: ref, mode: .edit(record.uuid))
        } label: {
          RowIcon(Image(systemName: "pencil"), label: row.editLabel)
        }
        Button {
          deleting = .record(record.uuid)
        } label: {
          RowIcon(Image(systemName: "trash"), label: row.deleteLabel)
        }
      }
      .buttonStyle(.borderless)
    }
  }

  private func failed(_ error: APIError, retry: @escaping () async -> Void) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(Self.failure(error))
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Button("Try again") { Task { await retry() } }
        .buttonStyle(.bordered)
    }
  }

  private var ref: RecordRef { .server(gearItem.uuid) }

  /// What follows a service's kind on its line: its label, then its day.
  private static func after(_ row: GearServiceCardContent.RecordRow) -> String {
    (row.label.map { " (\($0))" } ?? "") + " · " + row.date
  }

  private var deletingTitle: String {
    switch deleting {
    case .record: "Delete service record"
    default: "Delete service schedule"
    }
  }

  private var isDeleting: Binding<Bool> {
    Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
  }

  private func delete(_ target: Deleting) {
    switch target {
    case .schedule(let uuid): queue(.deleteServiceSchedule(.server(uuid), gearItem: ref))
    case .record(let uuid): queue(.deleteServiceRecord(.server(uuid), gearItem: ref))
    }
  }

  private func queue(_ operation: OutboxOperation) {
    queueError = GearItemDetailModel.queue(operation, in: outbox)
  }
}

extension GearServiceCard {
  /// What a list that could not be read says: offline, that it shows once it can be.
  static func failure(_ error: APIError) -> String {
    error.isUnreachable ? OfflineText.gearServiceNotShown : error.message
  }
}

/// One of a row's wordless controls, named for what it does to which row.
private struct RowIcon: View {
  let image: Image
  let label: String

  init(_ image: Image, label: String) {
    self.image = image
    self.label = label
  }

  var body: some View {
    image
      .frame(width: 32, height: 32)
      .contentShape(.rect)
      .accessibilityLabel(label)
  }
}

#Preview {
  let json = #"""
    {"uuid":"01a20000-0000-7000-8000-0000000000b1","name":"Twinset","brand":"Faber",
    "type":"cylinder","notes":"","rented":false,"volume":12,"working_pressure":232,
    "material":"steel","user_uuid":"01a20000-0000-7000-8000-000000000099",
    "is_archived":false,"archived_at":null,"dive_count":42,"dive_time":137520,"service":[],
    "created_at":"2026-01-02T10:00:00Z"}
    """#
  let session = DivePreviewData.session
  if let item = try? APICoding.decoder().decode(GearItemRead.self, from: Data(json.utf8)) {
    NavigationStack {
      ScrollView {
        GearServiceCard(
          gearItem: item, service: GearServiceModel(session: session, gearItemUUID: item.uuid)
        )
        .padding()
      }
    }
    .environment(session)
    .environment(OutboxModel(session: session))
  }
}
