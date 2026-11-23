import OpenDivingKit
import SwiftUI

/// The list to choose from: every dive on the computer that the logbook lacks, newest first,
/// each as a dive card with its start, length and max depth, none chosen to begin with. The
/// count and the confirmation stand in ``ChosenDivesBar`` under the list, where a long list
/// leaves them in reach.
struct ChooseDivesSections: View {
  let model: DiveComputerModel
  @Environment(Session.self) private var session

  var body: some View {
    Section {
      Button(model.choseAll ? DiveComputerText.chooseNone : DiveComputerText.chooseAll) {
        if model.choseAll { model.chooseNone() } else { model.chooseAll() }
      }
      .accentRow()
      Button("Cancel", role: .cancel) { model.cancel() }
        .accentRow()
    } header: {
      Text(
        model.choice?.checked == false
          ? DiveComputerText.onComputerHeading : DiveComputerText.notInLogbookHeading)
    } footer: {
      if model.choice?.checked == false {
        Text(DiveComputerText.logbookNotChecked)
      }
    }
    Section {
      ForEach(model.choiceRows(units: session.units)) { row in
        ChoiceRowView(row: row) { model.toggle(row.fingerprint) }
      }
    }
  }
}

/// One dive of the list: its card, with a mark saying whether it is chosen.
private struct ChoiceRowView: View {
  let row: DownloadChoice.Row
  let toggle: () -> Void

  var body: some View {
    Button(action: toggle) {
      DiveCardView(content: row.card)
        .overlay(alignment: .topTrailing) {
          Image(systemName: row.chosen ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .symbolRenderingMode(.palette)
            .foregroundStyle(row.chosen ? Color.white : Color.secondary, Color.accentText)
            .background(Circle().fill(.regularMaterial))
            .padding(10)
            .accessibilityHidden(true)
        }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(row.chosen ? .isSelected : [])
    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    .listRowBackground(Color.clear)
    .listRowSeparator(.hidden)
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  let engine = DiveComputerEngine(
    session: session, makeLink: { LibDCDiveComputerLink(manager: nil, defaults: .standard) },
    generator: DiveComputerView.generator)
  Form { ChooseDivesSections(model: DiveComputerModel(engine: engine)) }
    .environment(session)
}
