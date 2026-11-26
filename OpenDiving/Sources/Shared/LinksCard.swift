import OpenDivingKit
import SwiftUI

/// A record's links on its page, each opening in the browser; nothing where it has none.
struct LinksCard: View {
  let links: [ShownLink]

  var body: some View {
    if !links.isEmpty {
      SectionCard(title: "Links", icon: .globe) {
        LinkList(links: links)
      }
    }
  }
}

#Preview {
  ScrollView {
    LinksCard(
      links: ShownLink.list([
        WebLink(url: "https://blueocean.example/booking", label: "Booking"),
        WebLink(url: "https://blueocean.example/"),
      ])
    )
    .padding()
  }
  .background(Color.pageBackground)
}
