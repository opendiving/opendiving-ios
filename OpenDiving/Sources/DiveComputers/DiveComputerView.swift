import OpenDivingKit
import SwiftUI
import UIKit

/// The *Dive Computers* screen: the phone's paired computers, the search for one to pair, and a
/// download the diver starts, which ends on its outcome while its dives are imported and
/// announced as any walk's are. Reached from the profile's dive-computer button and from a
/// download's notification.
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

/// The screen over the app's download model, which a preview or a test gives a fake link:
/// the paired computers in the account's order, each with its line, *Which computer comes
/// first?* while a computer just paired waits for it, *Allow notifications*, the download in
/// flight, whoever started it, *Pair a dive computer*, and *Import files*. Leaving it
/// mid-download leaves the download running.
struct DiveComputerScreen: View {
  let downloads: DiveComputerDownloads
  @State private var showing: DiveComputerRecord?
  @Environment(\.scenePhase) private var scenePhase

  private var model: DiveComputerModel { downloads.model }

  var body: some View {
    List {
      if let question = model.orderQuestion {
        OrderQuestionSection(model: model, question: question)
      }
      paired
      if model.offersNotifications {
        Section {
          Button(DiveComputerText.allowNotifications) {
            Task { await model.allowNotifications() }
          }
          .accentRow()
        } footer: {
          Text(DiveComputerText.notificationsSentence)
        }
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
      DiveComputerWalkSections(model: model)
      if model.phase == .idle || model.phase == .scanning || model.phase == .finished {
        pairing
      }
      Section {
        NavigationLink {
          ImportView()
        } label: {
          Label(row: DiveComputerText.importFiles, icon: .upload)
        }
      } footer: {
        Text(DiveComputerText.importFilesFooter)
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      ChosenDivesBar(model: model)
    }
    .navigationTitle(DiveComputerText.screenTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if model.canReorder {
        ToolbarItem(placement: .primaryAction) { EditButton() }
      }
    }
    .task(id: ObjectIdentifier(model)) { await model.watch() }
    .task(id: ObjectIdentifier(model)) { await model.appeared() }
    .onAppear { downloads.screenAppeared() }
    .onDisappear { downloads.screenDisappeared() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { model.appBecameActive() }
    }
    .navigationDestination(item: $showing) { record in
      DiveComputerPage(model: model, record: record) {
        model.forget(record)
        showing = nil
      }
      // It counts as the screen, whose model would otherwise close with a download's outcome.
      .onAppear { downloads.screenAppeared() }
      .onDisappear { downloads.screenDisappeared() }
    }
  }

  /// Each paired computer with its line, opening its page; reordered in edit mode where the
  /// account's order can be set.
  @ViewBuilder private var paired: some View {
    if !model.paired.isEmpty {
      Section {
        ForEach(model.paired) { paired in
          NavigationRow {
            showing = paired.record
          } label: {
            VStack(alignment: .leading, spacing: 2) {
              Text(paired.title).foregroundStyle(.primary)
              Text(model.status(paired.record)).font(.caption).foregroundStyle(.secondary)
            }
          }
        }
        .onMove(
          perform: model.canReorder
            ? { source, destination in model.move(from: Array(source), to: destination) } : nil)
      } header: {
        Text(DiveComputerText.pairedHeading)
      } footer: {
        if model.paired.count > 1 {
          Text(DiveComputerText.orderFooter)
        }
      }
    }
  }

  /// *Pair a dive computer*, then the search it starts and the computers it finds.
  @ViewBuilder private var pairing: some View {
    if model.searching {
      Section {
        Text(DiveComputerText.scanningInstruction)
          .foregroundStyle(.secondary)
        ForEach(model.unpairedRows) { row in
          Button {
            model.connect(row)
          } label: {
            VStack(alignment: .leading, spacing: 2) {
              Text(row.title)
                .foregroundStyle(model.blocker == nil ? .primary : .secondary)
              if let subtitle = row.subtitle {
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
              }
            }
          }
          .disabled(model.blocker != nil)
        }
      } header: {
        HStack(spacing: 8) {
          Text(DiveComputerText.scanningHeading)
          if model.phase == .scanning { BubbleSpinner() }
        }
      }
    } else {
      Section {
        Button(DiveComputerText.pair) { model.pair() }
          .accentRow()
      }
    }
  }
}

/// The download the diver started, or one a connection started, as it stands: connecting, which
/// dives to download, downloading, the time-zone question, then its outcome. The list and the
/// computer's page both draw it.
struct DiveComputerWalkSections: View {
  let model: DiveComputerModel

  var body: some View {
    switch model.phase {
    case .idle, .scanning:
      EmptyView()
    case .connecting:
      Section {
        if let identity = model.identity {
          Text(identity.title).font(.headline)
        }
        HStack(spacing: 8) {
          BubbleSpinner()
          Text(model.connectingText ?? DiveComputerText.connecting)
        }
        if let waiting = model.waitingText {
          Text(waiting).foregroundStyle(.secondary)
        }
        Button("Cancel", role: .cancel) { model.cancel() }
          .accentRow()
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
            BubbleSpinner()
            Text(text)
          }
        }
        if let progress = model.progress {
          // In the bar's row, so a download with no estimate yet draws no empty one.
          VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: progress)
              .tint(Color.accentText)
            TimelineView(.periodic(from: .now, by: 1)) { context in
              if let timeLeft = model.timeLeftText(at: context.date) {
                Text(timeLeft).font(.caption).foregroundStyle(.secondary)
              }
            }
          }
        }
        Button("Cancel", role: .cancel) { model.cancel() }
          .accentRow()
      } footer: {
        Text(DiveComputerText.lockHint)
      }
    case .choosingDives:
      switch model.choice?.stage {
      case .question?: DiveQuestionSection(model: model)
      case .list?: ChooseDivesSections(model: model)
      case nil: EmptyView()
      }
    case .askingTimeZone:
      TimeZoneQuestion(model: model)
    case .finished:
      if let outcome = model.outcome {
        Section {
          Text(outcome.sentence)
          if model.offersChoosing {
            Button(DiveComputerText.chooseDives) { model.chooseDives() }
              .accentRow()
          } else if model.offersDownloadAll {
            Button(DiveComputerText.downloadAll) { model.downloadAll() }
              .accentRow()
          }
        }
      }
    }
  }
}

/// *Which computer comes first?*, one button per computer, the new one first.
private struct OrderQuestionSection: View {
  let model: DiveComputerModel
  let question: DiveComputerModel.OrderQuestion

  var body: some View {
    Section {
      Button(question.record.title) { Task { await model.answerOrder(newFirst: true) } }
        .accentRow()
      Button(question.other) { Task { await model.answerOrder(newFirst: false) } }
        .accentRow()
    } header: {
      Text(DiveComputerText.orderQuestion)
    } footer: {
      Text(DiveComputerText.orderQuestionDetail)
    }
    .disabled(model.answeringOrder)
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
        .accentRow()
      Button("Cancel", role: .cancel) { model.cancel() }
        .accentRow()
    }
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  let engine = DiveComputerEngine(
    session: session, makeLink: { LibDCDiveComputerLink(manager: nil, defaults: .standard) },
    generator: DiveComputerView.generator)
  NavigationStack {
    DiveComputerScreen(downloads: DiveComputerDownloads(engine: engine))
  }
  .environment(session)
}
