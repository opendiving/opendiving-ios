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
        Label(SettingsSection.invitations.title, systemImage: "envelope.badge.person.crop")
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
  @State private var codeFrame = CGRect.zero
  @State private var toggleFrame = CGRect.zero
  @State private var headerFrame = CGRect.zero
  /// The top bar's QR symbol, in the window, where the code ends.
  @State private var barIconFrame = CGRect.zero
  @State private var isOpen = false
  @State private var release = FoldRelease()
  /// Counts each slide from one end to the other, for its haptic as it starts.
  @State private var slides = 0

  private var progress: Double {
    InviteQRPaneScroll.progress(offset: geometry.offset, fold: pageHeight)
  }

  var body: some View {
    let progress = progress
    let controlsOpacity = max(1 - progress * 2, 0)
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
      }
      .coordinateSpace(.inviteQRFold)
      .onGeometryChange(for: CGRect.self) {
        $0.frame(in: .global)
      } action: {
        contentFrame = $0
      }
      .overlay(alignment: .topLeading) { code(progress: progress) }
      .overlay { invitesTitle(progress: progress) }
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
    .onChange(of: progress) {
      if progress >= 1 {
        isOpen = true
      } else if progress <= 0 {
        isOpen = false
      }
    }
    .onScrollPhaseChange { old, new in
      if old == .interacting, new != .interacting { slideOnRelease() }
    }
    .sensoryFeedback(.impact, trigger: slides)
    .toolbar {
      FoldTitle(isOpen: isOpen, symbolShare: Self.symbolShare(progress), close: close) {
        barIconFrame = $0
      }
    }
  }

  private func page(opacity: Double) -> some View {
    VStack(spacing: 16) {
      if let lastUpdated = model.lastUpdated {
        LastUpdatedLine(date: lastUpdated)
          .opacity(opacity)
      }
      // Where the code is drawn at the top, by `code(progress:)` above the scroll's content.
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
      .opacity(opacity)
      .allowsHitTesting(opacity > 0)
      Spacer(minLength: 24)
      Button(action: open) {
        VStack(spacing: 2) {
          // Drawn by `invitesTitle(progress:)`, which carries it up to head the list.
          Text(InvitationsModel.invitesToggle)
            .font(Self.toggleFont)
            .foregroundStyle(.clear)
            .onGeometryChange(for: CGRect.self) {
              $0.frame(in: .inviteQRFold)
            } action: {
              toggleFrame = $0
            }
          Image(systemName: "chevron.down")
            .font(.footnote.weight(.semibold))
            .opacity(opacity)
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
      Text(InvitationsModel.invitesToggle)
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
              .padding(.leading, 16)
          }
        }
        ShowOlderInvitations(model: model)
          .padding(.vertical, 12)
      }
      .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
      if let failure = model.revokeFailure ?? model.loadMoreFailure {
        FieldMessage(failure)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding([.horizontal, .bottom])
    .padding(.top, 8)
  }

  /// The code, moving from its place in the page to the top bar's middle as the pane scrolls,
  /// crossing to the symbol over the last stretch, until the bar's own button takes its place.
  @ViewBuilder private func code(progress: Double) -> some View {
    if !isOpen {
      let frame = Self.interpolate(codeFrame, iconFrame, progress)
      let symbol = Self.symbolShare(progress)
      ZStack {
        InviteQRCode(address: address.absoluteString, label: InvitationsModel.qrLabel)
          .opacity(1 - symbol)
          .accessibilityHidden(progress >= 0.5)
        Image(systemName: "qrcode")
          .resizable()
          .scaledToFit()
          .foregroundStyle(.primary)
          .opacity(symbol)
          .accessibilityHidden(true)
      }
      .frame(width: frame.width, height: frame.height)
      .offset(x: frame.minX, y: frame.minY)
      .allowsHitTesting(false)
    }
  }

  /// *Invites*, rising from the foot of the page to head the list and growing as it goes.
  private func invitesTitle(progress: Double) -> some View {
    let scale =
      headerFrame.height > 0 ? toggleFrame.height / headerFrame.height : 1
    let from = CGPoint(x: toggleFrame.midX, y: toggleFrame.midY)
    let to = CGPoint(x: headerFrame.midX, y: headerFrame.midY)
    return Text(InvitationsModel.invitesToggle)
      .font(Self.headerFont)
      .foregroundStyle(.primary)
      .fixedSize()
      .scaleEffect(scale + (1 - scale) * progress)
      .position(
        x: from.x + (to.x - from.x) * progress, y: from.y + (to.y - from.y) * progress
      )
      .accessibilityHidden(true)
      .allowsHitTesting(false)
  }

  /// Where the code ends: on the top bar's symbol, in the scroll's content, which moves under the
  /// bar as the pane scrolls.
  private var iconFrame: CGRect {
    barIconFrame.offsetBy(dx: -contentFrame.minX, dy: -contentFrame.minY)
  }

  private func open() {
    slides += 1
    withAnimation(Self.slide) { scroll.scrollTo(y: pageHeight) }
  }

  private func close() {
    slides += 1
    withAnimation(Self.slide) { scroll.scrollTo(edge: .top) }
  }

  /// Carries a released drag to the end it settles on at a slide's pace, which the scroll's own
  /// deceleration, slow from a slow drag, would reach long after.
  private func slideOnRelease() {
    guard let target = release.target, let start = release.start, target <= pageHeight else {
      return
    }
    release.target = nil
    if abs(target - start) > 1 { slides += 1 }
    withAnimation(Self.slide) { scroll.scrollTo(y: target) }
  }

  private static var toggleFont: Font { .subheadline.weight(.semibold) }
  private static var headerFont: Font { .title2.bold() }
  /// A sheet's slide, rather than a scroll's glide, once a finger lets go or a button is tapped.
  private static var slide: Animation { .spring(duration: 0.35, bounce: 0) }

  /// How far the code has crossed to the symbol: over the last two fifths of the way.
  private static func symbolShare(_ progress: Double) -> Double {
    min(max((progress - 0.6) / 0.4, 0), 1)
  }

  private static func interpolate(_ from: CGRect, _ to: CGRect, _ share: Double) -> CGRect {
    let mix = { (a: Double, b: Double) in a + (b - a) * share }
    return CGRect(
      x: mix(from.minX, to.minX), y: mix(from.minY, to.minY),
      width: mix(from.width, to.width), height: mix(from.height, to.height))
  }
}

/// The top bar's middle: the title while the code shows, then the code's own symbol under a
/// chevron, which takes it back. The symbol is there throughout, unseen until the pane opens, so
/// the code has somewhere to shrink to.
private struct FoldTitle: ToolbarContent {
  let isOpen: Bool
  let symbolShare: Double
  let close: () -> Void
  let onIconFrame: (CGRect) -> Void

  var body: some ToolbarContent {
    ToolbarItem(placement: .principal) {
      ZStack {
        Text("Your invite link")
          .font(.headline)
          .opacity(1 - symbolShare)
        Button(action: close) {
          VStack(spacing: 2) {
            Image(systemName: "chevron.up")
              .font(.caption2.weight(.semibold))
              .opacity(symbolShare)
            Image(systemName: "qrcode")
              .opacity(isOpen ? 1 : 0)
              .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .global)
              } action: {
                onIconFrame($0)
              }
          }
          .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(InvitationsModel.showQRCode)
        .accessibilityHidden(!isOpen)
        .allowsHitTesting(isOpen)
      }
    }
  }
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
    guard fold > 0 else { return }
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
}

extension CoordinateSpaceProtocol where Self == NamedCoordinateSpace {
  /// The fold's whole scrolled content, where the code and the icon it shrinks into are placed.
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
