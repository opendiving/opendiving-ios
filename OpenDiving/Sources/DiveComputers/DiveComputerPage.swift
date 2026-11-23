import OpenDivingKit
import SwiftUI

/// One paired computer, opened from *Paired Computers*: *Download automatically*, a download of
/// its new dives or of dives chosen from a list, what it has reported of itself, and forgetting
/// it.
struct DiveComputerPage: View {
  let model: DiveComputerModel
  /// The record the list opened, read again from the model as it changes.
  let opened: DiveComputerRecord
  let forget: () -> Void
  @State private var forgetting: DiveComputerRecord?

  init(model: DiveComputerModel, record: DiveComputerRecord, forget: @escaping () -> Void) {
    self.model = model
    opened = record
    self.forget = forget
  }

  private var record: DiveComputerRecord { model.record(opened.id) ?? opened }
  private var content: DiveComputerPageContent { DiveComputerPageContent(record) }

  var body: some View {
    Form {
      Section {
        Toggle(
          DiveComputerText.downloadAutomatically,
          isOn: Binding(
            get: { record.downloadsAutomatically },
            set: { model.setDownloadsAutomatically($0, for: record) })
        )
        .tint(.brandTeal)
      } footer: {
        Text(DiveComputerText.downloadAutomaticallyFooter)
      }
      switch model.pageWalk(record) {
      case .running:
        DiveComputerWalkSections(model: model)
      case .finished(let outcome):
        Section { Text(outcome.sentence) }
        downloadButtons
      case .none:
        downloadButtons
      }
      Section {
        ForEach(content.facts) { fact in
          LabeledContent(fact.label, value: fact.value)
        }
      }
      Section {
        Button(DiveComputerText.forget, role: .destructive) { forgetting = record }
          .dangerRow()
          .forgetDiveComputerConfirmation(record: $forgetting) { _ in forget() }
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if model.pageWalk(record) == .running {
        ChosenDivesBar(model: model)
      }
    }
    .navigationTitle(content.title)
    .navigationBarTitleDisplayMode(.inline)
  }

  private var downloadButtons: some View {
    Section {
      Button(DiveComputerText.downloadNew) { model.download(record, choosing: false) }
        .accentRow()
        .disabled(!model.canDownload(record))
      Button(model.canChoose(record) ? DiveComputerText.chooseDives : DiveComputerText.downloadAll)
      {
        model.download(record, choosing: true)
      }
      .accentRow()
      .disabled(!model.canDownload(record))
    } footer: {
      if let blocker = model.blocker {
        Text(blocker)
      }
    }
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  let engine = DiveComputerEngine(
    session: session, makeLink: { LibDCDiveComputerLink(manager: nil, defaults: .standard) },
    generator: DiveComputerView.generator)
  NavigationStack {
    DiveComputerPage(
      model: DiveComputerModel(engine: engine),
      record: DiveComputerRecord(
        identity: DiveComputerIdentity(
          family: .shearwaterPetrel, vendor: "Shearwater", product: "Perdix 3",
          serial: "D9772626", firmware: "93", hardware: "0B0B", familyNumber: 0, modelNumber: 14),
        lastDownloaded: Date()),
      forget: {})
  }
}
