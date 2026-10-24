import OpenDivingKit
import SwiftUI

/// What the phone holds that the server does not have yet, above the Dives list: the drafts,
/// the writes waiting, what could not be saved, what is done but said once, and the files
/// waiting to be read — each row omitted when it counts nothing, and the whole section when
/// they all do. Tapping it opens the pending screen.
struct PendingSection: View {
  @Environment(OutboxModel.self) private var outbox
  @Environment(InboxModel.self) private var inbox

  var body: some View {
    let summary = Self.summary(outbox, inbox)
    if !summary.isEmpty {
      NavigationLink {
        PendingScreen()
      } label: {
        PendingSummaryCard(summary: summary)
      }
      .buttonStyle(.plain)
    }
  }
}

extension PendingSection {
  /// The rows the section draws over the account's stores.
  static func summary(_ outbox: OutboxModel, _ inbox: InboxModel) -> PendingSummary {
    PendingSummary(
      drafts: outbox.drafts, items: outbox.items, notices: outbox.notices,
      unreadable: outbox.unreadable.count, files: inbox.files.count)
  }
}

/// The section's card: one line per row, and the chevron that says it opens.
struct PendingSummaryCard: View {
  let summary: PendingSummary

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 8) {
        ForEach(summary.rows) { row in
          Label(row.text, systemImage: Self.systemImage(row))
            .foregroundStyle(Self.isWarning(row) ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Image(systemName: "chevron.right")
        .foregroundStyle(.tertiary)
        .accessibilityHidden(true)
    }
    .font(.subheadline)
    .padding(12)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
  }

  private static func systemImage(_ row: PendingSummary.Row) -> String {
    switch row {
    case .drafts: "doc.text"
    case .waiting: "arrow.triangle.2.circlepath"
    case .failed: "exclamationmark.triangle"
    case .notice: "info.circle"
    case .unreadable: "questionmark.folder"
    case .files: "tray.and.arrow.down"
    }
  }

  private static func isWarning(_ row: PendingSummary.Row) -> Bool {
    if case .failed = row { true } else { false }
  }
}

#Preview {
  NavigationStack {
    PendingSection()
  }
  .environment(OutboxModel(session: DivePreviewData.session))
  .environment(InboxModel(session: DivePreviewData.session))
}
