import OpenDivingKit
import SwiftUI

/// What an import wrote, straight after the apply and from the history alike, with the offer to
/// renumber where it tangled the log's numbering. `onDone` is the way back where the screen has no
/// back button of its own to offer.
struct ImportResultSections: View {
  let result: LogbookImportRead
  let numbering: RenumberSuggestion?
  let units: UnitSystem
  var onDone: (() -> Void)?

  @State private var isRenumbering = false
  @State private var renumbered = false

  var body: some View {
    Section {
      VStack(alignment: .leading, spacing: 2) {
        Text("Imported").font(.headline)
        if let line = ImportText.appliedLine(result.appliedAt) {
          Text(line).font(.subheadline).foregroundStyle(.secondary)
        }
      }
    }
    ImportBodySections(read: result, units: units)
    if let numbering {
      Section {
        if renumbered {
          Text(DiveNumberingText.renumbered).font(.footnote).foregroundStyle(.secondary)
        } else {
          Text(numbering.text).font(.footnote).foregroundStyle(.secondary)
          Button("Renumber") { isRenumbering = true }
            .accentRow()
        }
      }
      .sheet(isPresented: $isRenumbering) {
        RenumberDivesSheet(defaults: numbering.defaults) { renumbered = true }
      }
    }
    ImportReportSections(report: result)
    Section {
      ImportLogLink(read: result) { Text("Import log") }
    }
    if let onDone {
      Section {
        Button("Done", action: onDone)
          .accentRow()
      }
    }
  }
}

#Preview {
  NavigationStack {
    List {
      ImportResultSections(
        result: ImportPreviewData.applied,
        numbering: RenumberSuggestion(
          text: "Numbered #1–#3 — 2 dives share a number. Renumbering from Sep 8, 2026 numbers "
            + "every dive from then on in date order.",
          defaults: RenumberDefaults(
            startAt: 3, fromDate: CalendarDate(year: 2026, month: 9, day: 8))), units: .metric
      ) {}
    }
  }
  .environment(DivePreviewData.session)
}
