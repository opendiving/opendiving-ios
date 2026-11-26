import OpenDivingKit
import SwiftUI

/// Links one under another, each by its label or its address.
struct LinkList: View {
  let links: [ShownLink]

  var body: some View {
    ForEach(Array(links.enumerated()), id: \.offset) { _, link in
      if let url = link.url {
        Link(destination: url) { Label(link.text, icon: .globe).lineLimit(1) }
          .accentRow()
      } else {
        Label(link.text, icon: .globe).lineLimit(1)
      }
    }
  }
}

#Preview {
  VStack(alignment: .leading, spacing: 8) {
    LinkList(links: [
      ShownLink(text: "Booking", url: URL(string: "https://blueocean.example/booking")),
      ShownLink(text: "not a url", url: nil),
    ])
  }
  .padding()
}
