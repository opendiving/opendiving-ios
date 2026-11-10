import Testing

@testable import OpenDivingKit

/// The panel is on the move from a finger's first pull until the last move begun lands, and takes
/// the detent it was heading for only then.
@MainActor
struct SiteFinderPanelDragTests {
  let panel = SiteFinderPanel(available: 800)

  @Test func aFingerPullingMovesIt() {
    let drag = SiteFinderPanelDrag()
    #expect(!drag.isMoving)
    drag.follow(30)
    #expect(drag.dragged == 30)
    #expect(drag.isMoving)
    #expect(drag.height(in: panel) == panel.height(.half) + 30)
  }

  @Test func itTakesTheDetentOnlyOnceTheMoveLands() {
    let drag = SiteFinderPanelDrag()
    drag.follow(30)
    let move = drag.begin()
    drag.head(to: .full)
    #expect(drag.detent == .half)
    #expect(drag.target == .full)
    #expect(drag.dragged == 0)
    #expect(drag.height(in: panel) == panel.height(.full))
    #expect(drag.isMoving)
    drag.end(move)
    #expect(drag.detent == .full)
    #expect(drag.heading == nil)
    #expect(drag.height(in: panel) == panel.height(.full))
    #expect(!drag.isMoving)
  }

  @Test func aMoveBegunSinceKeepsItMoving() {
    let drag = SiteFinderPanelDrag()
    let first = drag.begin()
    drag.follow(10)
    drag.end(first)
    #expect(drag.isMoving)
  }

  @Test func aFingerCatchingItOnTheWayPullsItFromWhereItWasHeading() {
    let drag = SiteFinderPanelDrag()
    let move = drag.begin()
    drag.head(to: .full)
    drag.follow(-40)
    #expect(drag.detent == .full)
    #expect(drag.heading == nil)
    #expect(drag.height(in: panel) == panel.height(.full) - 40)
    drag.end(move)
    #expect(drag.isMoving)
  }
}
