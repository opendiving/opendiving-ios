import OpenDivingKit
import SwiftUI

/// A gear item's service schedules, with their status, and its service history, each a card of
/// rows under its title and the button that adds to it, under the item page's *Service* tab. A
/// row opens its form, where it is deleted; a schedule is logged against, paused and resumed from
/// its swipe actions and its context menu. Each write is queued: a pause or resume shows on its
/// row at once, anything else once it lands.
struct GearServiceCard: View {
  let gearItem: GearItemRead
  let service: GearServiceModel
  /// The form a row opens, which the page pushes: a lazy stack cannot hold the destination.
  @Binding var route: GearServiceRoute?

  @Environment(Session.self) private var session
  @Environment(OutboxModel.self) private var outbox
  @State private var lookups: LookupsModel?
  @State private var queueError: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      if GearServiceCardContent.hasPendingWrite(outbox.items, gearItem: gearItem.uuid) {
        PendingEditLine()
      }
      VStack(alignment: .leading, spacing: 6) {
        header("Schedules", icon: .calendar) {
          NavigationLink {
            ServiceScheduleFormView(gearItem: ref, mode: .create, gearType: gearItem.type)
          } label: {
            Label("Add schedule", systemImage: "plus")
              .font(.subheadline)
          }
          .brandBorderedButton()
        }
        schedules
      }
      VStack(alignment: .leading, spacing: 6) {
        header("Service History", icon: .history) {
          NavigationLink {
            ServiceRecordFormView(gearItem: ref, mode: .create)
          } label: {
            Label("Log service", systemImage: "plus")
              .font(.subheadline)
          }
          .brandBorderedButton()
        }
        history
      }
    }
    .task { if lookups == nil { lookups = LookupsModel(session: session) } }
    .alert(
      "Not saved",
      isPresented: Binding(get: { queueError != nil }, set: { if !$0 { queueError = nil } })
    ) {
      Button("OK") {}
    } message: {
      Text(queueError ?? "")
    }
  }

  private func header(_ title: String, icon: Icon, @ViewBuilder action: () -> some View)
    -> some View
  {
    HStack(spacing: 8) {
      SectionTitle(title: title, icon: icon)
      Spacer()
      action()
    }
  }

  @ViewBuilder private var schedules: some View {
    switch service.schedules.phase {
    case .idle, .loading:
      card { spinner }
    case .failed(let error):
      card { failed(error) { await service.schedules.load() } }
    case .loaded where service.schedules.items.isEmpty:
      card { message(GearServiceCardContent.noSchedules) }
    case .loaded:
      card {
        ForEach(Array(service.schedules.items.enumerated()), id: \.element.id) { index, schedule in
          if index > 0 {
            Divider().padding(.leading, 16)
          }
          scheduleRow(schedule)
        }
      }
    }
  }

  private func scheduleRow(_ schedule: GearServiceScheduleRead) -> some View {
    let isActive = service.isActive(schedule, items: outbox.items)
    let row = GearServiceCardContent.row(
      schedule, isActive: isActive, diveCount: gearItem.diveCount, diveTime: gearItem.diveTime,
      today: CalendarDate.today())
    let toggleTitle = isActive ? "Pause" : "Resume"
    let toggleSymbol = isActive ? "pause" : "play"
    return Button {
      route = .editSchedule(schedule.uuid)
    } label: {
      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(row.kind).fontWeight(.medium)
          if let label = row.label {
            Text("(\(label))").foregroundStyle(.secondary)
          }
          Spacer(minLength: 8)
          if row.isPaused {
            BadgeView("Paused", style: .outline)
          } else if let status = row.status {
            BadgeView(status.text, style: status.style)
          }
        }
        Text(row.intervals)
          .font(.caption)
          .foregroundStyle(.secondary)
        if let due = row.due {
          Text(due).font(.caption).foregroundStyle(.secondary)
        }
      }
      .rowPadding()
      // The context menu lifts the row, and a swipe slides it, on its own fill.
      .background(Color.cardFill)
    }
    .buttonStyle(.plain)
    .contentShape(.contextMenuPreview, .formSection)
    .contextMenu {
      Button {
        route = .logService(schedule: schedule.uuid)
      } label: {
        Label("Log service", icon: .clipboardCheck)
      }
      Button(toggleTitle, systemImage: toggleSymbol) { toggle(schedule, to: !isActive) }
    }
    .rowSwipeActions(
      leading: [
        RowSwipeAction(title: "Log", image: Image(.clipboardCheck), fill: .brandTeal) {
          route = .logService(schedule: schedule.uuid)
        }
      ],
      trailing: [
        RowSwipeAction(
          title: toggleTitle, image: Image(systemName: toggleSymbol), fill: Color(.systemGray)
        ) { toggle(schedule, to: !isActive) }
      ])
  }

  private func toggle(_ schedule: GearServiceScheduleRead, to active: Bool) {
    queue(
      .updateServiceSchedule(
        .server(schedule.uuid), gearItem: ref, GearServiceScheduleUpdate(active: active)))
  }

  @ViewBuilder private var history: some View {
    switch service.records.phase {
    case .idle, .loading:
      card { spinner }
    case .failed(let error):
      card { failed(error) { await service.records.load() } }
    case .loaded where service.records.items.isEmpty:
      card { message(GearServiceCardContent.noRecords) }
    case .loaded:
      card {
        ForEach(Array(service.records.items.enumerated()), id: \.element.id) { index, record in
          if index > 0 {
            Divider().padding(.leading, 16)
          }
          recordRow(record)
        }
        PageEndTrigger(list: service.records)
      }
      LoadMoreFooter(list: service.records)
    }
  }

  private func recordRow(_ record: GearServiceRecordRead) -> some View {
    let row = GearServiceCardContent.row(record, contacts: lookups?.contacts ?? [])
    return Button {
      route = .editRecord(record.uuid)
    } label: {
      VStack(alignment: .leading, spacing: 2) {
        Self.title(row)
        if let servicedBy = row.servicedBy {
          Text(servicedBy).foregroundStyle(.secondary)
        }
        if let notes = row.notes {
          Text(notes).foregroundStyle(.secondary)
        }
      }
      .font(.subheadline)
      .rowPadding()
    }
    .buttonStyle(.plain)
  }

  /// A card of rows, each drawing its own padding.
  private func card(@ViewBuilder _ rows: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      rows()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.cardFill, in: .formSection)
    .clipShape(.formSection)
  }

  private var spinner: some View {
    BubbleSpinner()
      .frame(maxWidth: .infinity)
      .rowPadding()
  }

  private func message(_ text: String) -> some View {
    Text(text)
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .rowPadding()
  }

  private func failed(_ error: APIError, retry: @escaping () async -> Void) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(Self.failure(error))
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Button("Try again") { Task { await retry() } }
        .brandBorderedButton()
    }
    .rowPadding()
  }

  private var ref: RecordRef { .server(gearItem.uuid) }

  /// A service's line: its day, then its kind and its label.
  private static func title(_ row: GearServiceCardContent.RecordRow) -> Text {
    let date = Text(row.date).fontWeight(.medium)
    let dot = Text(" · ").foregroundStyle(.secondary)
    let kind = Text(row.kind).fontWeight(.medium)
    let label = Text(row.label.map { " (\($0))" } ?? "").foregroundStyle(.secondary)
    return Text("\(date)\(dot)\(kind)\(label)")
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

  /// The form `route` names, for the item `gearItem`.
  @ViewBuilder static func form(_ route: GearServiceRoute, gearItem: UUID) -> some View {
    switch route {
    case .logService(let schedule):
      ServiceRecordFormView(gearItem: .server(gearItem), mode: .create, schedule: schedule)
    case .editSchedule(let uuid):
      ServiceScheduleFormView(gearItem: .server(gearItem), mode: .edit(uuid))
    case .editRecord(let uuid):
      ServiceRecordFormView(gearItem: .server(gearItem), mode: .edit(uuid))
    }
  }
}

/// The form a row of the service cards opens.
enum GearServiceRoute: Hashable {
  case logService(schedule: UUID)
  case editSchedule(UUID)
  case editRecord(UUID)
}

extension View {
  /// A row's padding on its card, which a whole row's width answers a tap on.
  fileprivate func rowPadding() -> some View {
    padding(.horizontal, 16)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(.rect)
  }
}

#Preview {
  @Previewable @State var route: GearServiceRoute?
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
          gearItem: item, service: GearServiceModel(session: session, gearItemUUID: item.uuid),
          route: $route
        )
        .padding()
      }
      .navigationDestination(item: $route) { GearServiceCard.form($0, gearItem: item.uuid) }
    }
    .environment(session)
    .environment(OutboxModel(session: session))
  }
}
