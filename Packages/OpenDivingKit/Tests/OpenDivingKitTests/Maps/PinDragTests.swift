import Testing

@testable import OpenDivingKit

struct PinDragTests {
  private let pin = PinDrag.Point(x: 100, y: 200)

  @Test func theHeldPinRidesAboveTheFinger() {
    let drag = PinDrag(pin: pin, finger: PinDrag.Point(x: 104, y: 205))
    #expect(drag.held == PinDrag.Point(x: 104, y: 205 - PinDrag.lift))
    #expect(drag.offset == PinDrag.Point(x: 4, y: 5 - PinDrag.lift))
  }

  @Test func aHoldReleasedWithoutADragDropsNothing() {
    var drag = PinDrag(pin: pin, finger: pin)
    #expect(drag.drop == nil)
    drag.moved(to: PinDrag.Point(x: 103, y: 203))
    #expect(drag.drop == nil)
  }

  @Test func aDragDropsWhereThePinIsDrawn() {
    var drag = PinDrag(pin: pin, finger: pin)
    drag.moved(to: PinDrag.Point(x: 160, y: 300))
    #expect(drag.drop == PinDrag.Point(x: 160, y: 300 - PinDrag.lift))
  }

  @Test func aFingerThatStraysAndComesBackHasStillDragged() {
    var drag = PinDrag(pin: pin, finger: pin)
    drag.moved(to: PinDrag.Point(x: 160, y: 300))
    drag.moved(to: pin)
    #expect(drag.drop == drag.held)
  }

  @Test func aTouchIsOnThePinWithinAFingertip() {
    #expect(PinDrag.isOnPin(pin, touch: PinDrag.Point(x: 120, y: 215)))
    #expect(!PinDrag.isOnPin(pin, touch: PinDrag.Point(x: 140, y: 200)))
  }
}
