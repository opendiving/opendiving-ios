import OpenDivingKit
import SwiftUI

/// What the phone holds that the server does not have yet, above the Dives list: the drafts,
/// the writes waiting, what could not be saved, what is done but said once, the files waiting
/// to import and the downloaded dives waiting to upload — each row omitted when it counts nothing, and the whole section when
/// they all do. Tapping it opens the pending screen. Where the downloaded dives stand as rows of
/// their own, as on the Dives tab, the card does not count them too.
struct PendingSection: View {
  var countsDownloads = true
  @Environment(OutboxModel.self) private var outbox
  @Environment(InboxModel.self) private var inbox
  @Environment(DiveComputerEngine.self) private var engine: DiveComputerEngine?

  var body: some View {
    let summary = Self.summary(outbox, inbox, engine, countsDownloads: countsDownloads)
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
  static func summary(
    _ outbox: OutboxModel, _ inbox: InboxModel, _ engine: DiveComputerEngine? = nil,
    countsDownloads: Bool = true
  ) -> PendingSummary {
    let counted = countsDownloads ? engine : nil
    let downloads =
      (counted?.archives ?? []).reduce(0) { $0 + $1.summary.dives }
      + (counted?.held ?? []).reduce(0) { $0 + $1.dives }
    return PendingSummary(
      drafts: outbox.drafts, items: outbox.items, notices: outbox.notices,
      unreadable: outbox.unreadable.count, files: inbox.files.count, downloads: downloads)
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
            .foregroundStyle(
              Self.isWarning(row) ? AnyShapeStyle(Color.danger) : AnyShapeStyle(.primary))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Image(systemName: "chevron.right")
        .foregroundStyle(.tertiary)
        .accessibilityHidden(true)
    }
    .font(.subheadline)
    .padding(12)
    .background(Color.cardFill, in: .formSection)
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
    case .downloads: "arrow.down.circle"
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
