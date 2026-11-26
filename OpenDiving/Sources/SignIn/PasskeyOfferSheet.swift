import OpenDivingKit
import SwiftUI

/// *Sign in faster next time*, in the web's words: *Add a passkey* runs the ceremony Settings
/// runs, and *Not now* answers the offer.
struct PasskeyOfferSheet: View {
  let model: PasskeyOfferModel
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    // It scrolls where even the tallest detent cannot hold it.
    ScrollView {
      content
    }
    .scrollBounceBehavior(.basedOnSize)
    // At the accessibility sizes half the screen holds the title and little more.
    .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium])
    .presentationDragIndicator(.visible)
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label {
        Text(PasskeyOfferModel.title)
          .font(.title3.bold())
          .fixedSize(horizontal: false, vertical: true)
      } icon: {
        Image(.keyRound)
          .foregroundStyle(Color.accentText)
      }
      Text(PasskeyOfferModel.sentence)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      if let message = model.message {
        FieldMessage(message)
      }
      VStack(spacing: 10) {
        FormCapsuleButton(
          title: PasskeyOfferModel.addButton, isBusy: model.isAdding, busyValue: "Adding"
        ) {
          Task { await model.add() }
        }
        Button(PasskeyOfferModel.notNowButton) { model.notNow() }
          .brandBorderedButton()
          .buttonBorderShape(.capsule)
          .controlSize(.large)
          .frame(maxWidth: .infinity)
          .disabled(model.isAdding)
      }
      .needsServer()
    }
    .padding(24)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  Color.clear
    .sheet(isPresented: .constant(true)) {
      PasskeyOfferSheet(model: PasskeyOfferModel(session: session))
    }
    .environment(session)
}
