import OpenDivingKit
import SwiftUI

extension View {
  /// Where a tapped download notification opens, signed in: the dive it imported, the import's
  /// page, or the Dive Computers screen, over whatever is in front.
  func noticeHost(_ route: NoticeRoute, session: Session) -> some View {
    modifier(NoticeHost(route: route, session: session))
  }
}

private struct NoticeHost: ViewModifier {
  @Bindable var route: NoticeRoute
  let session: Session

  func body(content: Content) -> some View {
    content
      .sheet(item: signedIn ? $route.opened : .constant(nil)) { opened in
        NavigationStack {
          Group {
            switch opened.target {
            case .dive(let uuid): DiveDetailView(diveUUID: uuid)
            case .importPage(let uuid): ImportDetailView(uuid: uuid)
            case .diveComputers: DiveComputerView()
            }
          }
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button("Done") { route.opened = nil }
            }
          }
        }
      }
  }

  private var signedIn: Bool {
    if case .signedIn = session.state { true } else { false }
  }
}
