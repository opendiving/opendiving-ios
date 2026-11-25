import OpenDivingKit
import SwiftUI

extension View {
  /// Where a tapped download notification or a link opens, signed in, over whatever is in front:
  /// the dive it imported, the import's page or the Dive Computers screen, a record's page, or a
  /// connect link's.
  func screenPresenterHost(_ presenter: ScreenPresenter, session: Session) -> some View {
    modifier(ScreenPresenterHost(presenter: presenter, session: session))
  }
}

private struct ScreenPresenterHost: ViewModifier {
  @Bindable var presenter: ScreenPresenter
  let session: Session

  func body(content: Content) -> some View {
    content
      .environment(presenter)
      .sheet(item: signedIn ? $presenter.opened : .constant(nil)) { opened in
        Group {
          switch opened.screen {
          case .link(.connect(let token)):
            // The form it opens has its own bar.
            ConnectLinkOpenView(token: token)
          case .notice(let target):
            closable { notice(target) }
          case .link(.record(let record)):
            closable { recordPage(record) }
          }
        }
        // A pull from the top closes the sheet rather than reading its page again.
        .environment(\.pullsToRefresh, false)
        .environment(presenter)
      }
  }

  private func closable(@ViewBuilder _ page: () -> some View) -> some View {
    NavigationStack {
      page()
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button("Close", systemImage: "xmark") { presenter.opened = nil }
          }
        }
    }
  }

  @ViewBuilder private func notice(_ target: DiveComputerNotice.Target) -> some View {
    switch target {
    case .dive(let uuid): DiveDetailView(diveUUID: uuid)
    case .importPage(let uuid): ImportDetailView(uuid: uuid)
    case .diveComputers: DiveComputerView()
    }
  }

  @ViewBuilder private func recordPage(_ record: AppLink.Record) -> some View {
    switch record {
    case .site(let uuid): SiteMapView(siteUUID: uuid)
    case .dive(let uuid): DiveDetailView(diveUUID: uuid)
    case .trip(let uuid): TripDetailView(tripUUID: uuid)
    case .person(let uuid): PersonDetailView(personUUID: uuid)
    case .gearItem(let uuid): GearItemDetailView(gearItemUUID: uuid)
    case .course(let uuid): CourseDetailView(courseUUID: uuid)
    case .species(let uuid): SpeciesDetailView(speciesUUID: uuid)
    case .importPage(let uuid): ImportDetailView(uuid: uuid)
    }
  }

  private var signedIn: Bool {
    if case .signedIn = session.state { true } else { false }
  }
}
