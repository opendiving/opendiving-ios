import OpenDivingKit
import SwiftUI

/// More's *Gear*: what is waiting to sync, then the diver's gear, archived items among them and
/// badged, each opening its page, and below it their gear sets, each opening its form — the
/// pages the phone has shown first, from its copy.
struct GearListView: View {
  @Environment(Session.self) private var session

  var body: some View {
    GearListContent(model: GearListModel(session: session))
  }
}

extension GearListView {
  static let title = "Gear"
  static let description =
    "Track the equipment you dive with, and group it into sets you can load into a dive in one click"
  static let gearTitle = "Your Gear"
  static let gearEmptyTitle = "No gear yet"
  static let gearEmptyMessage =
    "Add your first piece of kit to start tracking what you dive with!"
  static let gearEmptyAction = "Add your first gear"
  static let setsTitle = "Gear Sets"
  static let setsEmptyTitle = "No gear sets yet"
  static let setsEmptyMessage =
    "Group the kit you use together — sidemount, tech, warm water — and load it into a dive in one click."
  static let setsEmptyAction = "Add your first set"

  /// What a failed first page of the gear says: offline, that it shows once it can be read.
  static func gearFailure(_ error: APIError) -> String {
    error.isUnreachable ? OfflineText.gearNotShown : "Failed to load gear. Please try again."
  }

  /// What a failed first page of the sets says.
  static func setsFailure(_ error: APIError) -> String {
    error.isUnreachable
      ? OfflineText.gearSetsNotShown : "Failed to load gear sets. Please try again."
  }
}

/// Where the list pushes a new record's form.
private enum GearCreate: Hashable {
  case gear, set
}

private struct GearListContent: View {
  @State var model: GearListModel
  @Environment(Session.self) private var session
  @State private var creating: GearCreate?

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        Text(GearListView.description)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
        // A queued create is not a row until it lands; what waits shows here however the
        // lists stand.
        PendingSection()
        gear
        sets
          .padding(.top, 12)
      }
      .padding()
    }
    .background(Color.pageBackground)
    .bubbleRefreshable { await model.refresh() }
    .navigationTitle(GearListView.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button("New gear") { creating = .gear }
          Button("New set") { creating = .set }
        } label: {
          Label("New", systemImage: "plus")
        }
      }
    }
    .navigationDestination(item: $creating) { create in
      switch create {
      case .gear: GearItemFormView(mode: .create)
      case .set: GearSetFormView(mode: .create)
      }
    }
    .task { await model.show() }
  }

  @ViewBuilder private var gear: some View {
    let list = model.items
    switch list.phase {
    case .idle, .loading:
      EmptyOrErrorView(status: .loading)
        .padding(.top, 32)
    case .failed(let error):
      EmptyOrErrorView(status: .failed(message: GearListView.gearFailure(error))) {
        Task { await list.refresh() }
      }
    case .loaded where list.items.isEmpty:
      empty(
        icon: .backpack, title: GearListView.gearEmptyTitle,
        message: GearListView.gearEmptyMessage, action: GearListView.gearEmptyAction
      ) { creating = .gear }
    case .loaded:
      ListHeading(title: GearListView.gearTitle, icon: .backpack)
      if let lastUpdated = list.lastUpdated {
        LastUpdatedLine(date: lastUpdated)
      }
      let today = CalendarDate.today()
      ForEach(list.items) { item in
        NavigationLink {
          GearItemDetailView(gearItemUUID: item.uuid)
        } label: {
          PlainCardView(content: .gearItem(item, units: session.units, today: today))
        }
        .buttonStyle(.plain)
        .task { await list.loadMore(after: item) }
      }
      LoadMoreFooter(list: list)
    }
  }

  @ViewBuilder private var sets: some View {
    let list = model.sets
    switch list.phase {
    case .idle, .loading:
      EmptyOrErrorView(status: .loading)
    case .failed(let error):
      EmptyOrErrorView(status: .failed(message: GearListView.setsFailure(error))) {
        Task { await list.refresh() }
      }
    case .loaded where list.items.isEmpty:
      empty(
        icon: .layers, title: GearListView.setsEmptyTitle,
        message: GearListView.setsEmptyMessage, action: GearListView.setsEmptyAction
      ) { creating = .set }
    case .loaded:
      ListHeading(title: GearListView.setsTitle, icon: .layers) {
        Button("New set", systemImage: "plus") { creating = .set }
          .font(.subheadline)
          .buttonStyle(.bordered)
      }
      if let lastUpdated = list.lastUpdated {
        LastUpdatedLine(date: lastUpdated)
      }
      ForEach(list.items) { set in
        NavigationLink {
          GearSetFormView(mode: .edit(set))
        } label: {
          PlainCardView(content: .gearSet(set, units: session.units))
        }
        .buttonStyle(.plain)
        .task { await list.loadMore(after: set) }
      }
      LoadMoreFooter(list: list)
    }
  }

  private func empty(
    icon: Icon, title: String, message: String, action: String, create: @escaping () -> Void
  ) -> some View {
    ContentUnavailableView {
      Label(title, icon: icon)
    } description: {
      Text(message)
    } actions: {
      Button(action, systemImage: "plus", action: create)
        .brandProminentButton()
    }
  }
}

/// A list's heading on the page, led by its symbol, with the list's own button where it has one.
private struct ListHeading<Trailing: View>: View {
  let title: String
  let icon: Icon
  @ViewBuilder var trailing: () -> Trailing

  var body: some View {
    HStack(spacing: 8) {
      Image(icon)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      Text(title)
        .font(.headline)
        .accessibilityAddTraits(.isHeader)
      Spacer()
      trailing()
    }
  }
}

extension ListHeading where Trailing == EmptyView {
  init(title: String, icon: Icon) {
    self.init(title: title, icon: icon) { EmptyView() }
  }
}

#Preview {
  NavigationStack {
    GearListView()
  }
  .environment(DivePreviewData.session)
  .environment(OutboxModel(session: DivePreviewData.session))
  .environment(InboxModel(session: DivePreviewData.session))
}
