import OpenDivingKit
import SwiftUI

/// *Settings* → *Appearance*: light, dark or the phone's own, for the whole app on this phone.
struct AppearanceScreen: View {
  @Environment(AppearanceModel.self) private var appearance

  var body: some View {
    List {
      Section {
        ForEach(Appearance.allCases) { choice in
          Button {
            appearance.choice = choice
          } label: {
            HStack {
              Label(row: choice.title, icon: choice.icon)
                .foregroundStyle(Color.primary)
              Spacer()
              if appearance.choice == choice {
                Image(systemName: "checkmark")
                  .foregroundStyle(Color.accentText)
                  .accessibilityHidden(true)
              }
            }
          }
          .accessibilityAddTraits(appearance.choice == choice ? .isSelected : [])
        }
      } footer: {
        Text("Kept on this phone, whichever server you are signed in to.")
      }
    }
    .navigationTitle("Appearance")
  }
}

#Preview {
  NavigationStack {
    AppearanceScreen()
  }
  .environment(AppearanceModel(defaults: .standard))
}
