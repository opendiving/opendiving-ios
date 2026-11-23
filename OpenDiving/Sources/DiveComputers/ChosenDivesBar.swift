import OpenDivingKit
import SwiftUI

/// Under the list to choose from, while it shows: how many dives are chosen and about how long
/// they would take, and the button that downloads them.
struct ChosenDivesBar: View {
  let model: DiveComputerModel

  var body: some View {
    if model.choice?.stage == .list {
      VStack(spacing: 8) {
        if let text = model.chosenText {
          Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        Button {
          model.downloadChosen()
        } label: {
          Text(DiveComputerText.downloadChosen(model.chosenCount))
            .frame(maxWidth: .infinity)
        }
        .brandProminentButton()
        .controlSize(.large)
        .disabled(model.chosenCount == 0)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(.bar)
    }
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  let engine = DiveComputerEngine(
    session: session, makeLink: { LibDCDiveComputerLink(manager: nil, defaults: .standard) },
    generator: DiveComputerView.generator)
  // Drawn only while a walk shows the list, so a preview with none draws nothing.
  ChosenDivesBar(model: DiveComputerModel(engine: engine))
}
