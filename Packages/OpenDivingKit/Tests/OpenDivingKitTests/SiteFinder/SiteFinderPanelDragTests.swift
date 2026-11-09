import Testing

@testable import OpenDivingKit

/// The panel is on the move from a finger's first pull until the last move begun lands.
@MainActor
struct SiteFinderPanelDragTests {
  @Test func aFingerPullingMovesIt() {
    let drag = SiteFinderPanelDrag()
    #expect(!drag.isMoving)
    drag.follow(30)
    #expect(drag.dragged == 30)
    #expect(drag.isMoving)
  }

  @Test func itRestsOnceTheMoveLands() {
    let drag = SiteFinderPanelDrag()
    drag.follow(30)
    let move = drag.begin()
    drag.letGo()
    #expect(drag.dragged == 0)
    #expect(drag.isMoving)
    drag.end(move)
    #expect(!drag.isMoving)
  }

  @Test func aMoveBegunSinceKeepsItMoving() {
    let drag = SiteFinderPanelDrag()
    let first = drag.begin()
    drag.follow(10)
    drag.end(first)
    #expect(drag.isMoving)
  }
}
