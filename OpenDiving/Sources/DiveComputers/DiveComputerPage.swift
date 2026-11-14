import OpenDivingKit
import SwiftUI

/// One paired computer, opened from *Paired Computers*: *Download automatically*, a download of
/// its new dives or of all of them, what it has reported of itself, and forgetting it.
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
            set: { model.setDownloadsAutomatically($0, for: record) }))
      } footer: {
        Text(DiveComputerText.downloadAutomaticallyFooter)
      }
      if model.isBusy || model.phase == .finished, model.walk?.isOf(record) == true {
        DiveComputerWalkSections(model: model)
      } else {
        Section {
          Button(DiveComputerText.downloadNew) { model.download(record, all: false) }
            .accentRow()
            .disabled(!model.canDownload(record))
          Button(DiveComputerText.downloadAll) { model.download(record, all: true) }
            .accentRow()
            .disabled(!model.canDownload(record))
        } footer: {
          if let blocker = model.blocker {
            Text(blocker)
          }
        }
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
    .navigationTitle(content.title)
    .navigationBarTitleDisplayMode(.inline)
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
