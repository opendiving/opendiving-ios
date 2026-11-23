import OpenDivingKit
import SwiftUI

/// The profile's QR button's pane: the diver's invite link as a QR code to show, its reset and
/// removal under it and the share in the top bar, or the way to make one while there is none.
struct InviteQRSheet: View {
  @Environment(Session.self) private var session

  var body: some View {
    InviteQRPane(session: session)
  }
}

private struct InviteQRPane: View {
  @State private var model: InvitationsModel
  @Environment(\.dismiss) private var dismiss

  init(session: Session) {
    _model = State(initialValue: InvitationsModel(session: session))
  }

  var body: some View {
    NavigationStack {
      Group {
        if model.hasInvitations, model.isLinkRead, let address = model.linkAddress {
          InviteQRFold(model: model, address: address) { linkControls }
        } else {
          ScrollView {
            VStack(spacing: 16) {
              content
            }
            .frame(maxWidth: .infinity)
            .padding()
          }
        }
      }
      .navigationTitle("Your invite link")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Close", systemImage: "xmark") { dismiss() }
        }
        if let address = model.linkAddress {
          ToolbarItem(placement: .topBarTrailing) {
            ShareLink(
              item: address, subject: Text(model.shareTitle),
              preview: SharePreview(model.shareTitle)
            ) {
              Label("Share", systemImage: "square.and.arrow.up")
            }
          }
        }
      }
    }
    .task { await model.load() }
    .task { await model.followRoute() }
  }

  @ViewBuilder private var content: some View {
    // Read again each time the pane opens; a read that fails leaves the phone's copy dated.
    if let lastUpdated = model.lastUpdated, !model.list.isAbsent {
      LastUpdatedLine(date: lastUpdated)
    }
    if model.list.isAbsent {
      ContentUnavailableView {
        Label(InvitationsModel.title, systemImage: "envelope.badge.person.crop")
      } description: {
        Text(InvitationsModel.openInstance)
      }
    } else if model.list.value == nil {
      OptionalListStatus(
        list: model.list, failed: InvitationsModel.loadFailed, loading: "Loading your invite link…")
    } else if !model.isLinkRead {
      if let failure = model.linkLoadFailure {
        Text(InvitationsModel.linkLoadFailed + " " + failure)
          .foregroundStyle(.secondary)
        Button("Try again") { Task { await model.loadLink() } }
          .needsServer()
          .accentRow()
      } else {
        HStack {
          BubbleSpinner()
          Text("Loading your invite link…")
        }
        .foregroundStyle(.secondary)
      }
    } else if let address = model.linkAddress {
      InviteQRCode(address: address.absoluteString, label: InvitationsModel.qrLabel)
      linkControls
    } else {
      Text(InvitationsModel.linkNone)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      Button {
        Task { await model.createLink() }
      } label: {
        Label(InvitationsModel.linkCreate, systemImage: "link")
          .frame(maxWidth: .infinity)
      }
      .brandProminentButton()
      .controlSize(.large)
      .disabled(model.isChangingLink)
      .needsServer()
      failure
    }
  }

  @ViewBuilder private var linkControls: some View {
    Text(InvitationsModel.linkLive)
      .font(.footnote)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
    HStack(spacing: 12) {
      changeButton(.reset)
      changeButton(.remove)
    }
    .controlSize(.large)
    failure
  }

  @ViewBuilder private var failure: some View {
    if model.isChangingLink {
      BubbleSpinner()
    } else if let failure = model.linkFailure {
      FieldMessage(failure)
    }
  }

  private func changeButton(_ change: InvitationsModel.LinkChange) -> some View {
    let isRemoval = change == .remove
    return Button(role: isRemoval ? .destructive : nil) {
      model.askToConfirm(change)
    } label: {
      Label(
        isRemoval ? InvitationsModel.removeButton : InvitationsModel.resetButton,
        systemImage: isRemoval ? "trash" : "arrow.counterclockwise"
      )
      .frame(maxWidth: .infinity)
    }
    .brandBorderedButton(isRemoval ? .danger : .accentText)
    .disabled(model.isChangingLink)
    .needsServer()
    .confirmsInviteLinkChange(change, model: model)
  }
}

/// The pane while there are invitations to show: the QR code over its controls, with *Invites*
/// at the foot. Scrolling on, or tapping it, carries the pane to the invitations below the fold
/// as the code shrinks into a button in the top bar where the title was, *Invites* rises to head
/// the list and the controls fade; scrolling back, or tapping that button, returns. The scroll
/// never rests between the two.
private struct InviteQRFold<Controls: View>: View {
  let model: InvitationsModel
  let address: URL
  @ViewBuilder let controls: Controls

  @State private var scroll = ScrollPosition(edge: .top)
  @State private var geometry = FoldGeometry()
  @State private var pageHeight = 0.0
  @State private var contentFrame = CGRect.zero
  @State private var scrollFrame = CGRect.zero
  @State private var codeFrame = CGRect.zero
  @State private var toggleFrame = CGRect.zero
  @State private var headerFrame = CGRect.zero
  /// The top bar's icon, in the window, where the code ends.
  @State private var barIconFrame = CGRect.zero
  @State private var chevronFrame = CGRect.zero
  @State private var controlsHeight = 0.0
  @State private var release = FoldRelease()
  @State private var slider = FoldSlider()
  /// Counts each switch between the code and the invitations, for its haptic.
  @State private var slides = 0

  /// How far the scroll has come from the code to the invitations, from 0 to 1.
  private var scrolled: Double {
    InviteQRPaneScroll.progress(offset: geometry.offset, fold: pageHeight)
  }

  /// How far the fold shows: ahead of the scroll in its middle, level with it at either end, so
  /// the code, the list and everything between move as one and land together.
  private var shown: Double { Self.lead(scrolled) }

  var body: some View {
    let shown = shown
    // The list rides the scroll; this keeps it where the fold shows it.
    let lift = (shown - scrolled) * pageHeight
    let controlsOpacity = 1 - InviteQRSymbol.fadeShare(shown)
    ScrollView {
      VStack(spacing: 0) {
        page(opacity: controlsOpacity)
          .frame(minHeight: geometry.visibleHeight, alignment: .top)
          .onGeometryChange(for: Double.self) {
            $0.size.height
          } action: {
            pageHeight = $0
          }
        invitations
          .frame(minHeight: geometry.visibleHeight, alignment: .top)
          .offset(y: -lift)
      }
      .coordinateSpace(.inviteQRFold)
      .onGeometryChange(for: CGRect.self) {
        $0.frame(in: .global)
      } action: {
        contentFrame = $0
      }
      .overlay { invitesTitle(progress: shown, lift: lift) }
    }
    // Over the scroll rather than in it: the code goes straight from its place to the bar, while
    // the page moves away under it, and clear of the blur the bar lays over the scroll's content.
    .overlay(alignment: .topLeading) { code(progress: shown) }
    .onGeometryChange(for: CGRect.self) {
      $0.frame(in: .global)
    } action: {
      scrollFrame = $0
    }
    .scrollIndicators(.hidden)
    .scrollPosition($scroll)
    .scrollTargetBehavior(FoldSettling(fold: pageHeight, release: release))
    .onScrollGeometryChange(for: FoldGeometry.self) {
      FoldGeometry(
        offset: $0.contentOffset.y + $0.contentInsets.top, visibleHeight: $0.containerSize.height)
    } action: {
      geometry = $1
    }
    .onScrollPhaseChange { old, new in
      if new == .interacting {
        slider.stop()
        release.isSliding = false
      } else if old == .interacting {
        slideOnRelease()
      }
    }
    .sensoryFeedback(.impact, trigger: slides)
    .toolbar {
      FoldTitle(
        address: address, isOpen: scrolled >= 1, titleOpacity: controlsOpacity,
        chevronOpacity: Self.chevronShare(shown), close: close,
        onIconFrame: { barIconFrame = $0 })
    }
  }

  private func page(opacity: Double) -> some View {
    VStack(spacing: Self.pageSpacing) {
      if let lastUpdated = model.lastUpdated {
        LastUpdatedLine(date: lastUpdated)
          .opacity(opacity)
      }
      // Where the code sits at rest, drawn by `code(progress:)` over the scroll.
      Color.clear
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 256)
        .onGeometryChange(for: CGRect.self) {
          $0.frame(in: .inviteQRFold)
        } action: {
          codeFrame = $0
        }
      VStack(spacing: 16) {
        controls
      }
      .onGeometryChange(for: Double.self) {
        $0.size.height
      } action: {
        controlsHeight = $0
      }
      .scaleEffect(1 - (1 - InviteQRSymbol.fadeScale) * (1 - opacity))
      .offset(y: controlsDrift)
      .opacity(opacity)
      .allowsHitTesting(opacity > 0)
      Spacer(minLength: 24)
      Button(action: open) {
        VStack(spacing: 2) {
          // Drawn by `invitesTitle(progress:)`, which carries it up to head the list.
          Text(InvitationsModel.invitesTitle)
            .font(Self.toggleFont)
            .foregroundStyle(.clear)
            .onGeometryChange(for: CGRect.self) {
              $0.frame(in: .inviteQRFold)
            } action: {
              toggleFrame = $0
            }
          Image(systemName: "chevron.down")
            .font(FoldChevron.font)
            .foregroundStyle(.clear)
            .onGeometryChange(for: CGRect.self) {
              $0.frame(in: .inviteQRFold)
            } action: {
              chevronFrame = $0
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .allowsHitTesting(opacity > 0)
    }
    .frame(maxWidth: .infinity)
    .padding([.horizontal, .top])
    .padding(.bottom, 8)
  }

  private var invitations: some View {
    VStack(spacing: 12) {
      Text(InvitationsModel.invitesTitle)
        .font(Self.headerFont)
        .foregroundStyle(.clear)
        .accessibilityAddTraits(.isHeader)
        .onGeometryChange(for: CGRect.self) {
          $0.frame(in: .inviteQRFold)
        } action: {
          headerFrame = $0
        }
        .frame(maxWidth: .infinity)
      VStack(spacing: 0) {
        let invitations = model.list.value?.invitations ?? []
        ForEach(invitations) { invitation in
          InvitationRow(model: model, invitation: invitation)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
          if invitation.id != invitations.last?.id || model.list.value?.hasMore == true {
            Divider()
              .padding(.horizontal, 16)
          }
        }
        ShowOlderInvitations(model: model)
          .padding(.vertical, 12)
      }
      .background(Color.cardFill, in: .formSection)
      if let failure = model.revokeFailure ?? model.loadMoreFailure {
        FieldMessage(failure)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding([.horizontal, .bottom])
    .padding(.top, Self.invitationsTop)
  }

  /// The code, moving from its place at rest straight to the top bar's middle as the pane scrolls
  /// and folding into its icon as it goes, until the bar's own icon takes its place.
  @ViewBuilder private func code(progress: Double) -> some View {
    if progress < 1 {
      let frame = codePath(progress: progress)
      InviteQRCode(
        address: address.absoluteString, label: InvitationsModel.qrLabel, morph: progress
      )
      .accessibilityHidden(progress >= 0.5)
      .frame(width: frame.width, height: frame.height)
      .offset(x: frame.minX, y: frame.minY)
      .allowsHitTesting(false)
    }
  }

  /// The code's frame in the scroll view, `progress` of the way from where it sits with the pane
  /// at rest on it to the bar's symbol.
  private func codePath(progress: Double) -> CGRect {
    let contentTopAtRest = contentFrame.minY + geometry.offset
    let atRest = codeFrame.offsetBy(
      dx: contentFrame.minX - scrollFrame.minX, dy: contentTopAtRest - scrollFrame.minY)
    let inBar = barIconFrame.offsetBy(dx: -scrollFrame.minX, dy: -scrollFrame.minY)
    return atRest.interpolated(to: inBar, by: progress)
  }

  /// *Invites*, rising from the foot of the page to head the list and growing as it goes, its
  /// chevron going with it as it fades.
  private func invitesTitle(progress: Double, lift: Double) -> some View {
    let centre = invitesCentre(progress: progress)
    let at = CGPoint(x: centre.x, y: centre.y - lift)
    return ZStack {
      Text(InvitationsModel.invitesTitle)
        .font(Self.headerFont)
        .foregroundStyle(.primary)
        .fixedSize()
        .scaleEffect(invitesScale(progress: progress))
        .position(at)
      Image(systemName: "chevron.down")
        .font(FoldChevron.font)
        .foregroundStyle(.primary)
        .opacity(1 - InviteQRSymbol.fadeShare(progress))
        .position(x: at.x, y: at.y + chevronFrame.midY - toggleFrame.midY)
    }
    .accessibilityHidden(true)
    .allowsHitTesting(false)
  }

  /// Where *Invites* is centred `progress` of the way up, in the scroll's content before the
  /// list's lift. Its place heading the list is reckoned from the layout, since the lift moves
  /// what a measure of it reads.
  private func invitesCentre(progress: Double) -> CGPoint {
    let heading = pageHeight + Self.invitationsTop + headerFrame.height / 2
    return CGPoint(
      x: toggleFrame.midX, y: toggleFrame.midY + (heading - toggleFrame.midY) * progress)
  }

  /// *Invites*' size `progress` of the way up, of its size heading the list.
  private func invitesScale(progress: Double) -> Double {
    let start = headerFrame.height > 0 ? toggleFrame.height / headerFrame.height : 1
    return start + (1 - start) * progress
  }

  /// How far the description and buttons stand from their place in the page: rising slower than
  /// the page, they are centred between the whole code's foot and *Invites* as they finish fading.
  private var controlsDrift: Double {
    let fade = InviteQRSymbol.fadeShare(shown)
    guard fade > 0, controlsHeight > 0 else { return 0 }
    let end = InviteQRSymbol.fadeEnd
    // From the content to the scroll view, now and with the pane at rest.
    let now = contentFrame.minY - scrollFrame.minY
    let atRest = now + geometry.offset
    let centre = codeFrame.maxY + Self.pageSpacing + controlsHeight / 2
    let invitesTop =
      invitesCentre(progress: end).y - invitesScale(progress: end) * headerFrame.height / 2
    let codeBottom = InviteQRCode.inkBottom(
      in: codePath(progress: end), address: address.absoluteString, morph: end)
    let between = (codeBottom + invitesTop + atRest - end * pageHeight) / 2
    let rest = centre + atRest
    return rest + (between - rest) * fade - (centre + now)
  }

  private func open() {
    slide(to: pageHeight, switching: true)
  }

  private func close() {
    slide(to: 0, switching: true)
  }

  /// Steps the scroll frame by frame, rather than animating it, which reports only where it ends
  /// and leaves the code and *Invites* nothing to follow on the way. A switch's haptic comes as
  /// the invitations start to rise, and as the code lands back in place.
  private func slide(to target: Double, switching: Bool) {
    if switching, target > 0 { slides += 1 }
    release.isSliding = true
    slider.slide(from: geometry.offset, to: target) { offset in
      scroll.scrollTo(y: offset)
    } done: {
      release.isSliding = false
      if switching, target == 0 { slides += 1 }
    }
  }

  /// Carries a released drag to the end it settles on at a slide's pace, which the scroll's own
  /// deceleration, slow from a slow drag, would reach long after.
  private func slideOnRelease() {
    guard let target = release.target, let start = release.start, target <= pageHeight else {
      return
    }
    release.target = nil
    slide(
      to: target,
      switching: InviteQRPaneScroll.switches(from: start, to: target, fold: pageHeight))
  }

  /// Between the page's lines: the date, the code, its description and buttons.
  private static var pageSpacing: Double { 16 }
  /// The room above *Invites* heading the list.
  private static var invitationsTop: Double { 8 }
  /// The fold's lead on the scroll at its middle, of the whole way.
  private static var leadShare: Double { 0.2 }

  /// `progress` with the fold's lead: monotonic, and level at 0 and 1.
  private static func lead(_ progress: Double) -> Double {
    progress + leadShare * 4 * progress * (1 - progress)
  }

  private static var toggleFont: Font { .subheadline.weight(.semibold) }
  private static var headerFont: Font { .title2.bold() }

  /// How far the bar's chevron has come in: over the last two fifths of the way.
  private static func chevronShare(_ progress: Double) -> Double {
    min(max((progress - 0.6) / 0.4, 0), 1)
  }

}

/// The top bar's middle: the title while the code shows, then the code's icon under a chevron,
/// which takes it back. The icon is there throughout, unseen until the pane opens, so the code has
/// somewhere to fold into.
private struct FoldTitle: ToolbarContent {
  let address: URL
  let isOpen: Bool
  let titleOpacity: Double
  let chevronOpacity: Double
  let close: () -> Void
  let onIconFrame: (CGRect) -> Void

  var body: some ToolbarContent {
    ToolbarItem(placement: .principal) {
      ZStack {
        Text("Your invite link")
          .font(.headline)
          .opacity(titleOpacity)
        // The icon alone sits on the line of the bar's buttons; the chevron rides above it.
        Button(action: close) {
          InviteQRCode(
            address: address.absoluteString, label: InvitationsModel.showQRCode, morph: 1
          )
          .frame(width: 20, height: 20)
          .opacity(isOpen ? 1 : 0)
          .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .global)
          } action: {
            onIconFrame($0)
          }
          .overlay(alignment: .top) {
            Image(systemName: "chevron.up")
              .font(FoldChevron.font)
              .foregroundStyle(.primary)
              .opacity(chevronOpacity)
              .alignmentGuide(.top) { $0[.bottom] + FoldChevron.gap }
          }
          // A bar button's reach, centred on the icon so it keeps its line, and tall enough to
          // take in the chevron.
          .frame(width: 48, height: 48)
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(InvitationsModel.showQRCode)
        .accessibilityHidden(!isOpen)
        .allowsHitTesting(isOpen)
      }
    }
  }
}

/// The chevrons either end of the fold: under *Invites* at the foot of the page, and over the
/// icon in the bar, at the same gap from what they point the way to.
private enum FoldChevron {
  static var font: Font { .footnote.weight(.semibold) }
  /// Between the bar's icon and the chevron over it: the gap under *Invites*, whose line keeps
  /// room below the letters on top of the stack's spacing.
  nonisolated static let gap = 5.0
}

/// The fold's scroll, counted from the top of the content as a scroll target is, rather than from
/// the scroll view's own origin, which sits the top bar's inset above it.
private struct FoldGeometry: Equatable {
  var offset = 0.0
  var visibleHeight = 0.0
}

/// Rests a scroll on the QR code or on the invitations, never between them, and leaves where a
/// drag began and where it rests in `release` for the fold to slide it there. A target is counted
/// from the top of the content, below the top bar's inset.
private struct FoldSettling: ScrollTargetBehavior {
  let fold: Double
  let release: FoldRelease

  func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
    guard fold > 0, !release.isSliding else { return }
    let start = context.originalTarget.rect.minY
    target.rect.origin.y = InviteQRPaneScroll.restingOffset(
      start: start, proposed: target.rect.minY, fold: fold)
    release.start = start
    release.target = target.rect.minY
  }
}

/// Where the last released drag began and where it rests, handed from the scroll's target to the
/// fold; a plain reference, since the scroll asks for a target while it lays out.
private final class FoldRelease {
  var start: Double?
  var target: Double?
  /// While the fold steps the scroll itself, whose every step the target would otherwise settle.
  var isSliding = false
}

/// Moves the fold's scroll from one offset to another over a sheet's slide, a step a frame,
/// easing out as a sheet settles.
private final class FoldSlider {
  private static let duration = 0.35

  private var link: CADisplayLink?
  private var from = 0.0
  private var to = 0.0
  private var start = 0.0
  private var step: ((Double) -> Void)?
  private var done: (() -> Void)?

  func slide(
    from: Double, to: Double, step: @escaping (Double) -> Void, done: @escaping () -> Void
  ) {
    stop()
    self.from = from
    self.to = to
    self.step = step
    self.done = done
    start = CACurrentMediaTime()
    let link = CADisplayLink(target: self, selector: #selector(tick))
    link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
    link.add(to: .main, forMode: .common)
    self.link = link
  }

  func stop() {
    link?.invalidate()
    link = nil
  }

  @objc private func tick(_ link: CADisplayLink) {
    let share = min((link.targetTimestamp - start) / Self.duration, 1)
    step?(from + (to - from) * (1 - pow(1 - share, 3)))
    guard share >= 1 else { return }
    stop()
    done?()
  }
}

extension CoordinateSpaceProtocol where Self == NamedCoordinateSpace {
  /// The fold's whole scrolled content, where the page's and the list's parts are measured.
  nonisolated fileprivate static var inviteQRFold: Self { .named("inviteQRFold") }
}

#Preview {
  Color.clear
    .sheet(isPresented: .constant(true)) { InviteQRSheet() }
    .environment(
      Session.stub(
        transport: StubTransport(routes: [
          "GET user/invitations": .json(
            #"{"data":[],"total_count":0,"has_more":false,"page":1,"items_per_page":20}"#),
          "GET user/invite-link": .json(
            #"{"token":"q7Zr2LmWexampleInviteTokenNotReal0123456","#
              + #""created_at":"2026-11-01T10:00:00Z"}"#),
        ])))
}

#Preview("With invitations") {
  Color.clear
    .sheet(isPresented: .constant(true)) { InviteQRSheet() }
    .environment(
      Session.stub(
        transport: StubTransport(routes: [
          "GET user/invitations": .json(
            #"{"data":[{"uuid":"019a4d5e-6f70-7182-9a3b-4c5d6e7f8a90","email":"sam@example.com","#
              + #""created_at":"2026-11-08T09:30:00Z","accepted_at":null,"revoked_at":null,"#
              + #""from_invite_link":false,"member_name":null},{"uuid":"#
              + #"019a4d5e-6f70-7182-9a3b-4c5d6e7f8a91","email":null,"#
              + #""created_at":"2026-11-02T18:00:00Z","accepted_at":"2026-11-02T18:00:00Z","#
              + #""revoked_at":null,"from_invite_link":true,"member_name":"Robin Diver"}],"#
              + #""total_count":2,"has_more":false,"page":1,"items_per_page":20}"#),
          "GET user/invite-link": .json(
            #"{"token":"q7Zr2LmWexampleInviteTokenNotReal0123456","#
              + #""created_at":"2026-11-01T10:00:00Z"}"#),
        ])))
}
