import OpenDivingKit
import SwiftUI

/// One of the sign-in screen's entries: its button, and an info button on the right opening an
/// alert with what it is.
struct SignedOutEntryRow<Title: View>: View {
  let infoTitle: String
  let info: String
  let infoLabel: String
  let action: () -> Void
  @ViewBuilder let title: Title

  @State private var showsInfo = false

  var body: some View {
    HStack {
      Button(action: action) {
        title
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
      }
      .accentRow()
      // Two buttons in one row: a style other than the default gives each its own taps rather
      // than the row's.
      .buttonStyle(.borderless)
      Button {
        showsInfo = true
      } label: {
        Image(systemName: "info.circle")
      }
      .accentRow()
      .buttonStyle(.borderless)
      .accessibilityLabel(infoLabel)
      .alert(infoTitle, isPresented: $showsInfo) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(info)
      }
    }
  }
}

#Preview {
  Form {
    SignedOutEntryRow(
      infoTitle: "Your check-in sheet", info: SignedOutEntry.checkInSheet.info(on: .flagship),
      infoLabel: "About your check-in sheet", action: {}
    ) {
      Label("Your check-in sheet", icon: .idCard)
    }
    .labelStyle(.titleAndIcon)
  }
}
