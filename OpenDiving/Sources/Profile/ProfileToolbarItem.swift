import OpenDivingKit
import SwiftUI

/// The sites map's way to the diver's profile: their picture, or their initials on the bar's
/// glass, a circle the size of the bar's own round buttons.
struct ProfileToolbarItem: ToolbarContent {
  let avatar: AvatarModel
  let onOpen: () -> Void

  var body: some ToolbarContent {
    // The bar's glass would pad the picture into a capsule and cut it short, so the button draws
    // its own circle. A glass of its own is carried into the next page's back button, which the
    // profile hides.
    if #available(iOS 26, *) {
      ToolbarItem(placement: .primaryAction) { button }
        .sharedBackgroundVisibility(.hidden)
    } else {
      ToolbarItem(placement: .primaryAction) { button }
    }
  }

  private var button: some View {
    Button(action: onOpen) {
      UserAvatarView(
        initials: avatar.initials, picture: avatar.data, side: MapRoundButtonStyle.side
      )
      // The page's colour, where the profile and *Account* ring theirs in the name's: over the
      // map's tiles it parts the picture from them.
      .overlay { Circle().strokeBorder(Color(.systemBackground), lineWidth: 1) }
      .pickerControl(in: Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Profile")
  }
}
