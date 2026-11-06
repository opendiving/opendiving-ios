import Testing

@testable import OpenDivingKit

/// When a form asks what is at its position, and when it must not.
@MainActor
struct PositionLookupTests {
  @Test func anUnansweredPositionWantsALookup() {
    let lookup = PositionLookup()
    #expect(lookup.request == nil)
    lookup.positionChanged(latitude: "27.8", longitude: "34.3")
    #expect(lookup.request != nil)
  }

  @Test func eachChangeIsANewRequest() {
    let lookup = PositionLookup()
    lookup.positionChanged(latitude: "27.8", longitude: "34.3")
    let first = lookup.request
    lookup.positionChanged(latitude: "27.85", longitude: "34.3")
    #expect(lookup.request != first)
  }

  @Test func comingBackToAnAnsweredPositionTakesTheRequestBack() {
    let lookup = PositionLookup()
    lookup.adopt(latitude: "27.8506", longitude: "34.3136", credit: "credit")
    lookup.positionChanged(latitude: "27.85061", longitude: "34.3136")
    #expect(lookup.request != nil)
    lookup.positionChanged(latitude: "27.8506", longitude: "34.3136")
    #expect(lookup.request == nil)
    #expect(lookup.credit(latitude: "27.8506", longitude: "34.3136") == "credit")
  }

  @Test func textThatIsNoPositionTakesTheRequestBack() {
    let lookup = PositionLookup()
    lookup.adopt(latitude: "27.8506", longitude: "34.3136", credit: "credit")
    lookup.positionChanged(latitude: "27.85", longitude: "34.3")
    lookup.positionChanged(latitude: "27.", longitude: "34.3")
    #expect(lookup.request == nil)
    lookup.positionChanged(latitude: "", longitude: "")
    #expect(lookup.request == nil)
  }

  @Test func askingNeedsNoChange() {
    let lookup = PositionLookup()
    lookup.ask()
    #expect(lookup.request != nil)
  }

  @Test func aFinishedRequestIsNotMadeAgain() {
    let lookup = PositionLookup()
    lookup.positionChanged(latitude: "27.8", longitude: "34.3")
    lookup.finishRequest()
    #expect(lookup.request == nil)
  }

  @Test func anAdoptedPickAskedAboutNothingFurther() {
    let lookup = PositionLookup()
    lookup.adopt(latitude: "27.8", longitude: "34.3", credit: nil)
    lookup.positionChanged(latitude: "27.8", longitude: "34.3")
    #expect(lookup.request == nil)
  }
}
