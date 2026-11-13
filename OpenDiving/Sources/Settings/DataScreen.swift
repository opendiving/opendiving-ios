import OpenDivingKit
import SwiftUI

/// *Settings* → *Data*: what the account's uploads take up, and the four downloads of its
/// logbook, each handed to the share sheet.
struct DataScreen: View {
  @Environment(Session.self) private var session

  var body: some View {
    DataList(session: session)
      .navigationTitle(SettingsSection.data.title)
      .followsAccount(session)
  }
}

private struct DataList: View {
  @State private var storage: StorageModel
  @State private var exports: DataExportModel

  init(session: Session) {
    _storage = State(initialValue: StorageModel(session: session))
    _exports = State(initialValue: DataExportModel(session: session))
  }

  var body: some View {
    List {
      StorageSection(model: storage)
      ExportSection(model: exports)
    }
    .sharesExports(exports)
  }
}

/// Used against the limit, or the no-limit sentence, then the breakdown by kind.
private struct StorageSection: View {
  let model: StorageModel

  var body: some View {
    Section {
      if let usage = model.usage {
        VStack(alignment: .leading, spacing: 8) {
          Text(StorageText.used(usage))
            .font(.subheadline.weight(.medium))
          if let limit = usage.limitBytes {
            ProgressView(value: Double(min(usage.usedBytes, limit)), total: Double(max(limit, 1)))
              .accessibilityLabel("Storage used")
              .accessibilityValue(StorageText.used(usage))
            if StorageText.isOverLimit(usage) {
              FieldMessage(StorageText.overLimit)
            }
          } else {
            FieldMessage(StorageText.noLimit, isNote: true)
          }
        }
        ForEach(StorageText.kinds(usage), id: \.label) { kind in
          HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
              Text(kind.label)
              if let attached = kind.attached {
                Text(attached)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            Spacer()
            Text(kind.size)
              .fontWeight(.medium)
              .monospacedDigit()
          }
        }
      } else if let failure = model.loadFailure {
        VStack(alignment: .leading, spacing: 8) {
          Text(StorageText.loadFailed + " " + failure)
            .foregroundStyle(.secondary)
          Button("Try again") { Task { await model.load() } }
            .buttonStyle(.borderless)
            .accentRow()
        }
      } else {
        HStack {
          BubbleSpinner()
          Text("Loading storage…")
        }
        .foregroundStyle(.secondary)
      }
    } header: {
      Text("Storage")
    } footer: {
      VStack(alignment: .leading, spacing: 8) {
        Text(StorageText.description)
        if model.usage != nil {
          Text(StorageText.compressedNote)
        }
      }
    }
    .task { await model.load() }
    .task { await model.followRoute() }
  }
}

/// A row per format, each downloading the whole logbook into the share sheet.
private struct ExportSection: View {
  let model: DataExportModel

  var body: some View {
    Section {
      ForEach(ExportFormat.allCases) { format in
        VStack(alignment: .leading, spacing: 8) {
          HStack(alignment: .firstTextBaseline) {
            Text(format.title)
              .font(.subheadline.weight(.medium))
            Spacer()
            button(format)
          }
          Text(format.summary)
            .font(.footnote)
            .foregroundStyle(.secondary)
          if let failure = model.failure, failure.format == format {
            FieldMessage(failure.message)
          }
        }
        .padding(.vertical, 4)
        // The Download label would otherwise pull the separator in to its title.
        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
      }
    } header: {
      Text("Data export")
    } footer: {
      Text(
        "Take a complete copy of your logbook, in formats other programs can read. Nothing here"
          + " is locked to OpenDiving.")
    }
  }

  @ViewBuilder
  private func button(_ format: ExportFormat) -> some View {
    if model.downloading == format {
      HStack(spacing: 6) {
        BubbleSpinner()
        Text("Preparing…")
      }
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Preparing \(format.title) export")
    } else {
      Button {
        model.start(format)
      } label: {
        Label("Download", systemImage: "arrow.down.circle")
      }
      .buttonStyle(.borderless)
      .accentRow()
      .disabled(model.isBusy)
      .accessibilityLabel("Download \(format.title)")
    }
  }
}

#Preview {
  NavigationStack {
    DataScreen()
  }
  .environment(
    Session.stub(
      transport: StubTransport(routes: [
        "GET user/storage": .json(
          #"{"used_bytes":137512960,"limit_bytes":1073741824,"dive_files_bytes":74842112,"#
            + #""certification_files_bytes":52428800,"pictures_bytes":10242048,"#
            + #""dive_files_count":12,"dives_with_files_count":9,"#
            + #""certification_files_count":4,"certifications_with_files_count":2}"#)
      ])))
}
