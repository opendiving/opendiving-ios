import OpenDivingKit
import Testing

/// The invite link pane rests on the QR code or on the invitations, never between them.
struct InviteQRPaneScrollTests {
  private let fold = 600.0

  @Test func aDragDownFromTheQRCodeReachesTheInvitationsOncePastTheThreshold() {
    #expect(InviteQRPaneScroll.restingOffset(start: 0, proposed: 59, fold: fold) == 0)
    #expect(InviteQRPaneScroll.restingOffset(start: 0, proposed: 60, fold: fold) == fold)
    #expect(InviteQRPaneScroll.restingOffset(start: 0, proposed: 900, fold: fold) == 900)
  }

  @Test func aDragUpFromTheInvitationsReachesTheQRCodeOncePastTheThreshold() {
    #expect(InviteQRPaneScroll.restingOffset(start: fold, proposed: 541, fold: fold) == fold)
    #expect(InviteQRPaneScroll.restingOffset(start: fold, proposed: 540, fold: fold) == 0)
    #expect(InviteQRPaneScroll.restingOffset(start: 1400, proposed: 300, fold: fold) == 0)
  }

  @Test func aScrollWithinTheInvitationsRestsWhereItWasHeaded() {
    #expect(InviteQRPaneScroll.restingOffset(start: 1400, proposed: 700, fold: fold) == 700)
    #expect(InviteQRPaneScroll.restingOffset(start: fold, proposed: 1200, fold: fold) == 1200)
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
