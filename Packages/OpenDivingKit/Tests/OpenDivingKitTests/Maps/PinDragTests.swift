import Testing

@testable import OpenDivingKit

struct PinDragTests {
  private let pin = PinDrag.Point(x: 100, y: 200)

  @Test func aHeldPinRisesStraightUpWhereverTheFingerLanded() {
    for finger in [
      PinDrag.Point(x: 120, y: 215), PinDrag.Point(x: 82, y: 190), pin,
    ] {
      let drag = PinDrag(pin: pin, finger: finger)
      #expect(drag.held == PinDrag.Point(x: 100, y: 200 - PinDrag.lift))
      #expect(drag.offset == PinDrag.Point(x: 0, y: -PinDrag.lift))
    }
  }

  @Test func aPinHeldOffCentreFollowsTheFingersMovement() {
    var drag = PinDrag(pin: pin, finger: PinDrag.Point(x: 120, y: 215))
    drag.moved(to: PinDrag.Point(x: 180, y: 315))
    #expect(drag.drop == PinDrag.Point(x: 160, y: 300 - PinDrag.lift))
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
