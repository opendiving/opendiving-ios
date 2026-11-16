import OpenDivingKit
import Testing

/// The invite link pane rests on the QR code or on the invitations, never between them.
struct InviteQRPaneScrollTests {
  private let fold = 600.0

  @Test func aDragDownFromTheQRCodeReachesTheInvitationsOncePastTheThreshold() {
    #expect(InviteQRPaneScroll.restingOffset(start: 0, proposed: 59, fold: fold) == 0)
    #expect(InviteQRPaneScroll.restingOffset(start: 0, proposed: 60, fold: fold) == fold)
  }

  @Test func aDragUpFromTheInvitationsReachesTheQRCodeOncePastTheThreshold() {
    #expect(InviteQRPaneScroll.restingOffset(start: fold, proposed: 541, fold: fold) == fold)
    #expect(InviteQRPaneScroll.restingOffset(start: fold, proposed: 540, fold: fold) == 0)
  }

  @Test func aScrollWithinTheInvitationsRestsWhereItWasHeaded() {
    #expect(InviteQRPaneScroll.restingOffset(start: 1400, proposed: 700, fold: fold) == 700)
    #expect(InviteQRPaneScroll.restingOffset(start: fold, proposed: 1200, fold: fold) == 1200)
  }

  @Test func oneGestureSwitchesOrScrollsTheInvitationsNeverBoth() {
    // A flick off the code that would carry into the list stops at its top.
    #expect(InviteQRPaneScroll.restingOffset(start: 0, proposed: 900, fold: fold) == fold)
    // A scroll up the list that would carry on to the code stops at the list's top.
    #expect(InviteQRPaneScroll.restingOffset(start: 1400, proposed: 300, fold: fold) == fold)
    #expect(InviteQRPaneScroll.restingOffset(start: 1400, proposed: 590, fold: fold) == fold)
  }

  @Test func onlyACrossingBetweenTheCodeAndTheInvitationsIsASwitch() {
    #expect(InviteQRPaneScroll.switches(from: 0, to: fold, fold: fold))
    #expect(InviteQRPaneScroll.switches(from: fold, to: 0, fold: fold))
    #expect(!InviteQRPaneScroll.switches(from: 1400, to: fold, fold: fold))
    #expect(!InviteQRPaneScroll.switches(from: 30, to: 0, fold: fold))
    #expect(!InviteQRPaneScroll.switches(from: fold, to: 1200, fold: fold))
  }

  @Test func aScrollThatDoesNotMoveRestsAtTheNearerEnd() {
    #expect(InviteQRPaneScroll.restingOffset(start: 200, proposed: 200, fold: fold) == 0)
    #expect(InviteQRPaneScroll.restingOffset(start: 400, proposed: 400, fold: fold) == fold)
  }

  @Test func progressRunsFromTheQRCodeToTheFoldAndStopsThere() {
    #expect(InviteQRPaneScroll.progress(offset: -40, fold: fold) == 0)
    #expect(InviteQRPaneScroll.progress(offset: 300, fold: fold) == 0.5)
    #expect(InviteQRPaneScroll.progress(offset: 2000, fold: fold) == 1)
    #expect(InviteQRPaneScroll.progress(offset: 300, fold: 0) == 0)
  }
}
