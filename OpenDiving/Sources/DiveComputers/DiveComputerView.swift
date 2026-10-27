import OpenDivingKit
import SwiftUI
import UIKit

/// The *Dive computer* screen: the computers found nearby, a download from the one the diver
/// picks, and the import screen once its dives are in the inbox. Reached from the Dives tab's
/// `+`, which only the signed-in shell shows.
struct DiveComputerView: View {
  @Environment(Session.self) private var session
  @Environment(InboxModel.self) private var inbox

  var body: some View {
    DiveComputerScreen(
      model: DiveComputerModel(
        session: session, inbox: inbox, link: LibDCDiveComputerLink(),
        generator: Self.generator))
  }

  /// What the archive's document names as its writer.
  static var generator: ComputerArchiveWriter.Generator {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    return ComputerArchiveWriter.Generator(name: "OpenDiving for iOS", version: version ?? "0")
  }
}

/// The screen over a model, which a preview or a test gives a fake link.
struct DiveComputerScreen: View {
  @State private var model: DiveComputerModel
  @State private var zone: TimeZone
  @State private var showsImport = false

  init(model: @autoclosure @escaping () -> DiveComputerModel) {
    _model = State(wrappedValue: model())
    _zone = State(initialValue: .current)
  }

  var body: some View {
    List {
      if let blocker = model.blocker {
        Section {
          Text(blocker)
          if model.availability == .refused {
            Button(DiveComputerText.openSettings) {
              if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
              }
            }
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
    .task { await model.watch() }
    .onDisappear { model.close() }
    .onChange(of: model.phase) { _, phase in
      if phase == .askingTimeZone { zone = model.suggestedZone }
    }
    .onChange(of: model.outcome) { _, outcome in
      if outcome?.kind == .handedOver { showsImport = true }
    }
    .navigationDestination(isPresented: $showsImport) { ImportView() }
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
        HStack(spacing: 8) {
          ProgressView()
          Text(DiveComputerText.connecting)
        }
        Button("Cancel", role: .cancel) { model.cancel() }
      }
    case .downloading:
      Section {
        if let identity = model.identity {
          Text(identity.title).font(.headline)
        }
        if let text = model.downloadingText {
          Text(text)
        }
        if let progress = model.progress {
          ProgressView(value: progress)
        }
        Button("Cancel", role: .cancel) { model.cancel() }
      } footer: {
        Text(DiveComputerText.lockHint)
      }
    case .askingTimeZone:
      Section(DiveComputerText.timeZoneQuestion) {
        TimeZonePicker(title: "Time zone", selection: $zone)
        Button("Continue") { model.answerTimeZone(zone) }
        Button("Cancel", role: .cancel) { model.cancel() }
      }
    case .finished:
      if let outcome = model.outcome {
        Section {
          Text(outcome.sentence)
          if outcome.offersDownloadAll {
            Button(DiveComputerText.downloadAll) { model.downloadAll() }
          }
        }
      }
    }
  }

  @ViewBuilder private var found: some View {
    if !model.rows.isEmpty {
      Section {
        ForEach(model.rows) { row in
          Button {
            model.connect(row)
          } label: {
            VStack(alignment: .leading, spacing: 2) {
              Text(row.title).foregroundStyle(.primary)
              if let subtitle = row.subtitle {
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
              }
            }
          }
          .disabled(model.blocker != nil)
        }
      }
    }
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  let inbox = InboxModel(session: session)
  NavigationStack {
    DiveComputerScreen(
      model: DiveComputerModel(
        session: session, inbox: inbox,
        link: LibDCDiveComputerLink(manager: nil, defaults: .standard),
        generator: DiveComputerView.generator))
  }
  .environment(session)
  .environment(inbox)
}
