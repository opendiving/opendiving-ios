import OpenDivingKit
import SwiftUI

/// The check-in sheet signed out, presented over sign-in: the phone's copy, with nothing to
/// refresh it from, and *Sign in to refresh* leading back.
struct CardsView: View {
  @Environment(Session.self) private var session

  var body: some View {
    NavigationStack {
      CardsScreen(session: session)
    }
  }
}

private struct CardsScreen: View {
  @State private var model: CheckinSheetModel
  @State private var pictures = PictureCache()
  @Environment(\.dismiss) private var dismiss

  init(session: Session) {
    _model = State(initialValue: CheckinSheetModel(session: session))
  }

  var body: some View {
    Group {
      if model.sheet != nil {
        ScrollView {
          CheckinSheetView(model: model, pictures: pictures)
            .padding()
        }
      } else {
        CheckinSheetView(model: model, pictures: pictures)
      }
    }
    .background(Color.pageBackground)
    .navigationTitle("Cards")
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Done") { dismiss() }
      }
    }
    .task { model.load() }
  }
}

#Preview {
  CardsView()
    .environment(Session.signedOutStub(transport: StubTransport(routes: [:])))
}
