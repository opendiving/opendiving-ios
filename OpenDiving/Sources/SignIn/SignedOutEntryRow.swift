import OpenDivingKit
import SwiftUI

/// One of the sign-in screen's entries: its button, and an info button on the right opening a
/// popover with what it is.
struct SignedOutEntryRow<Title: View>: View {
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
      .popover(isPresented: $showsInfo) {
        Text(info)
          .font(.subheadline)
          .fixedSize(horizontal: false, vertical: true)
          .padding()
          .frame(width: 300)
          .presentationCompactAdaptation(.popover)
      }
    }
  }
}

#Preview {
  Form {
    SignedOutEntryRow(
      info: SignedOutEntry.checkInSheet.info(on: .flagship), infoLabel: "About your check-in sheet",
      action: {}
    ) {
      Label("Your check-in sheet", icon: .idCard)
    }
    .labelStyle(.titleAndIcon)
  }
}
