import OpenDivingKit
import SwiftUI

/// The sites map's way to the diver's profile: their picture, or their initials on the bar's
/// glass, a circle the size of the bar's own round buttons.
struct ProfileToolbarItem: ToolbarContent {
  let avatar: AvatarModel

  var body: some ToolbarContent {
    // The toolbar's own glass pads a custom label into a capsule; the button draws its own
    // circle, as the dive-computer button does.
    if #available(iOS 26, *) {
      ToolbarItem(placement: .primaryAction) { link }
        .sharedBackgroundVisibility(.hidden)
    } else {
      ToolbarItem(placement: .primaryAction) { link }
    }
  }

  private var link: some View {
    NavigationLink {
      ProfileView(avatar: avatar)
    } label: {
      UserAvatarView(initials: avatar.initials, picture: avatar.data, side: 44)
        .pickerControl(in: Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Profile")
  }
}
