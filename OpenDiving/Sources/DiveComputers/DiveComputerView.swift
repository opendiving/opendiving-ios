import OpenDivingKit
import SwiftUI
import UIKit

/// The *Dive Computers* screen: the account's paired computers, the others found nearby, a
/// download from the one the diver picks, and the import screen once its dives are in the inbox.
/// Reached from the Dives tab's dive-computer button, which only the signed-in shell shows.
struct DiveComputerView: View {
  @Environment(DiveComputerDownloads.self) private var downloads

  var body: some View {
    DiveComputerScreen(downloads: downloads)
  }

  /// What the archive's document names as its writer.
  static var generator: ComputerArchiveWriter.Generator {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    return ComputerArchiveWriter.Generator(name: "OpenDiving for iOS", version: version ?? "0")
  }
}

/// The screen over the shell's download model, which a preview or a test gives a fake link.
/// Leaving it mid-download leaves the download running.
struct DiveComputerScreen: View {
  let downloads: DiveComputerDownloads
  @State private var showsImport = false
  @State private var showing: DiveComputerRecord?

  private var model: DiveComputerModel { downloads.model }

  var body: some View {
    List {
      if model.phase == .idle || model.phase == .scanning || model.phase == .finished {
        paired
      }
      if let blocker = model.blocker {
        Section {
          Text(blocker)
          if model.availability == .refused {
            Button(DiveComputerText.openSettings) {
              if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
              }
            }
            .accentRow()
          }
        }
      }
      phase
      if model.phase == .idle || model.phase == .scanning || model.phase == .finished {
        found
      }
    }
    .navigationTitle(DiveComputerText.screenTitle)
    .navigationBarTitleDisplayMode(.inline)
    .task(id: ObjectIdentifier(model)) { await model.watch() }
    .onAppear {
      // A download that handed its dives over while the screen was away goes on to the import.
      if downloads.screenAppeared()?.kind == .handedOver { showsImport = true }
    }
    .onDisappear { downloads.screenDisappeared() }
    .onChange(of: model.outcome) { _, outcome in
      if outcome?.kind == .handedOver { showsImport = true }
    }
    .navigationDestination(isPresented: $showsImport) { ImportView() }
    .navigationDestination(item: $showing) { record in
      DiveComputerPage(record: record) {
        model.forget(record)
        showing = nil
      }
      // It counts as the screen, whose model would otherwise close with a download's outcome.
      .onAppear { downloads.screenAppeared() }
      .onDisappear { downloads.screenDisappeared() }
    }
  }

  @ViewBuilder private var phase: some View {
    switch model.phase {
    case .idle, .scanning:
      Section {
        Text(DiveComputerText.scanningInstruction)
          .foregroundStyle(.secondary)
      } header: {
        HStack(spacing: 8) {
          Text(DiveComputerText.scanningHeading)
          if model.phase == .scanning { ProgressView() }
        }
      }
    case .connecting:
      Section {
        if let identity = model.identity {
          Text(identity.title).font(.headline)
        }
        HStack(spacing: 8) {
          DiveComputerSpinner()
          Text(model.connectingText ?? DiveComputerText.connecting)
        }
        if let waiting = model.waitingText {
          Text(waiting).foregroundStyle(.secondary)
        }
        Button("Cancel", role: .cancel) { model.cancel() }
      }
    case .downloading:
      Section {
        if let identity = model.identity {
          Text(identity.title).font(.headline)
        }
        if let counts = model.countsText {
          Text(counts)
        }
        // While the computer is busy with another app, the waiting line stands in for the counter.
        if let text = model.waitingText ?? model.downloadingText {
          HStack(spacing: 8) {
            DiveComputerSpinner()
            Text(text)
          }
        }
        if let progress = model.progress {
          ProgressView(value: progress)
        }
        Button("Cancel", role: .cancel) { model.cancel() }
      } footer: {
        Text(DiveComputerText.lockHint)
      }
    case .askingTimeZone:
      TimeZoneQuestion(model: model)
    case .finished:
      if let outcome = model.outcome {
        Section {
          Text(outcome.sentence)
          if outcome.offersDownloadAll {
            Button(DiveComputerText.downloadAll) { model.downloadAll() }
              .accentRow()
          }
        }
      }
    }
  }

  /// Each paired computer, which connects while the scan sees it and opens its page from the
  /// info button whether it does or not.
  @ViewBuilder private var paired: some View {
    if !model.paired.isEmpty {
      Section(DiveComputerText.pairedHeading) {
        ForEach(model.paired) { paired in
          let connects = paired.row != nil && model.blocker == nil
          HStack {
            Button {
              if let row = paired.row { model.connect(row) }
            } label: {
              label(paired.title, paired.subtitle, connects: connects)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            // Two buttons in one row: a style other than the default gives each its own taps
            // rather than the row's.
            .buttonStyle(PairedRowButtonStyle())
            .disabled(!connects)
            Button {
              showing = paired.record
            } label: {
              Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(DiveComputerText.about(paired.title))
          }
        }
      }
    }
  }

  @ViewBuilder private var found: some View {
    if !model.unpairedRows.isEmpty {
      Section {
        ForEach(model.unpairedRows) { row in
          Button {
            model.connect(row)
          } label: {
            label(row.title, row.subtitle, connects: model.blocker == nil)
          }
          .disabled(model.blocker != nil)
        }
      }
    }
  }

  /// A computer's row, its title dimmed where it does not connect — a paired computer the scan
  /// does not see.
  private func label(_ title: String, _ subtitle: String?, connects: Bool) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title).foregroundStyle(connects ? .primary : .secondary)
      if let subtitle {
        Text(subtitle).font(.caption).foregroundStyle(.secondary)
      }
    }
  }
}

/// A paired computer's row, which dims on a press and otherwise keeps the label's own colours:
/// `.plain` would dim a computer out of reach a second time over its secondary text.
private struct PairedRowButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.opacity(configuration.isPressed ? 0.5 : 1)
  }
}

/// *Which time zone were these dives in?*, opening on the zone the model offers, whether the
/// question opens under the diver or was already open when they came back to the screen.
private struct TimeZoneQuestion: View {
  let model: DiveComputerModel
  @State private var zone: TimeZone

  init(model: DiveComputerModel) {
    self.model = model
    _zone = State(initialValue: model.suggestedZone)
  }

  var body: some View {
    Section(DiveComputerText.timeZoneQuestion) {
      TimeZonePicker(title: "Time zone", selection: $zone)
      Button("Continue") { model.answerTimeZone(zone) }
      Button("Cancel", role: .cancel) { model.cancel() }
    }
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  let inbox = InboxModel(session: session)
  NavigationStack {
    DiveComputerScreen(
      downloads: DiveComputerDownloads {
        DiveComputerModel(
          session: session, inbox: inbox,
          link: LibDCDiveComputerLink(manager: nil, defaults: .standard),
          generator: DiveComputerView.generator)
      })
  }
  .environment(session)
  .environment(inbox)
}
