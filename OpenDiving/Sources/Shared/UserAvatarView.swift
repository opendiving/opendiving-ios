import OpenDivingKit
import SwiftUI
import UIKit

/// The diver's picture in a circle `side` across, or their initials where there is none — a
/// person where there is no name to take them from — drawn over nothing of its own, so the host
/// lays the circle on its own ground.
struct UserAvatarView: View {
  let initials: String?
  let picture: Data?
  let side: CGFloat

  @State private var image: UIImage?

  var body: some View {
    ZStack {
      if let image {
        Image(uiImage: image)
          .renderingMode(.original)
          .resizable()
          .scaledToFill()
      } else if let initials {
        // The web's proportion: its 36 px circle sets its initials at 14.
        Text(initials)
          .font(.system(size: side * 0.4, weight: .medium))
      } else {
        Image(.user)
          .resizable()
          .scaledToFit()
          .padding(side / 4)
      }
    }
    .frame(width: side, height: side)
    .clipShape(Circle())
    .contentShape(Circle())
    .onChange(of: picture, initial: true) { _, picture in
      image = picture.flatMap(UIImage.init(data:))
    }
    .accessibilityHidden(true)
  }
}

#Preview {
  HStack(spacing: 16) {
    UserAvatarView(initials: "TD", picture: nil, side: 44)
    UserAvatarView(initials: "A", picture: nil, side: 44)
    UserAvatarView(initials: nil, picture: nil, side: 44)
    UserAvatarView(initials: "TD", picture: nil, side: 56)
  }
  .padding()
  .background(Color(.secondarySystemBackground))
}
