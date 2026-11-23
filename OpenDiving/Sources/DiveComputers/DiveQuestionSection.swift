import OpenDivingKit
import SwiftUI

/// *Which dives do you want to download?*, asked once a computer new to the account has listed
/// its dives: how many the logbook lacks and about how long they would take, then all of them,
/// the list, only future ones, or *Cancel*.
struct DiveQuestionSection: View {
  let model: DiveComputerModel

  var body: some View {
    Section {
      if let detail = model.questionDetail {
        Text(detail)
      }
      Button(model.downloadAllText ?? "") { model.downloadAllListed() }
        .accentRow()
      Button(DiveComputerText.chooseFromList) { model.showList() }
        .accentRow()
      Button(DiveComputerText.onlyFutureDives) { model.onlyFutureDives() }
        .accentRow()
      Button("Cancel", role: .cancel) { model.cancel() }
        .accentRow()
    } header: {
      Text(DiveComputerText.diveQuestion)
    } footer: {
      if model.choice?.checked == false {
        Text(DiveComputerText.logbookNotChecked)
      }
    }
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  let engine = DiveComputerEngine(
    session: session, makeLink: { LibDCDiveComputerLink(manager: nil, defaults: .standard) },
    generator: DiveComputerView.generator)
  // With no walk at the question the section draws its buttons alone.
  Form { DiveQuestionSection(model: DiveComputerModel(engine: engine)) }
}
