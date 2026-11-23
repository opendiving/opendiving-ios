import OpenDivingKit
import SwiftUI

/// A dive of a download on its way to the logbook, as a dive card that opens where the diver can
/// act on what holds it: *Dive Computers* or *Waiting to Sync*.
struct DownloadRowView: View {
  let row: DownloadRow

  var body: some View {
    NavigationLink {
      switch row.opens {
      case .diveComputers: DiveComputerView()
      case .waitingToSync: PendingScreen()
      }
    } label: {
      DiveCardView(content: row.card)
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  let facts = ListedDiveFacts(
    start: .wallClock(
      LocalDateTime(date: CalendarDate(year: 2026, month: 10, day: 26)!, hour: 15, minute: 3)!),
    length: 4577, maxDepth: 47.7)
  let rows = DownloadRow.rows(
    onComputer: [
      DownloadRow.Listed(
        uuid: nil, fingerprint: Data([1]), computer: "Shearwater Perdix 3", facts: facts,
        watchZone: nil, inTransfer: true),
      DownloadRow.Listed(
        uuid: nil, fingerprint: Data([2]), computer: "Shearwater Perdix 3",
        facts: ListedDiveFacts(), watchZone: nil, inTransfer: false),
    ],
    onPhone: [
      DiveOnPhone(
        id: UUID(), computer: "Suunto Ocean", facts: nil, watchZone: nil, wait: .route,
        archive: UUID())
    ],
    units: .metric)
  NavigationStack {
    ScrollView {
      VStack(spacing: 12) {
        ForEach(rows) { DownloadRowView(row: $0) }
      }
      .padding()
    }
    .background(Color(.systemGroupedBackground))
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
