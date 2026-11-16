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
/// as the code shrinks into the icon above them and the controls fade; scrolling back, or tapping
/// the icon, returns. The scroll never rests between the two.
private struct InviteQRFold<Controls: View>: View {
  let model: InvitationsModel
  let address: URL
  @ViewBuilder let controls: Controls

  @State private var scroll = ScrollPosition(edge: .top)
  @State private var geometry = FoldGeometry()
  @State private var pageHeight = 0.0
  @State private var codeFrame = CGRect.zero
  @State private var iconFrame = CGRect.zero
  @State private var isOpen = false

  private static var iconSide: Double { 44 }

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
        invitations(isOpen: progress >= 1)
          .frame(minHeight: geometry.visibleHeight, alignment: .top)
      }
      .coordinateSpace(.inviteQRFold)
      .overlay(alignment: .topLeading) { code(progress: progress) }
    }
    .scrollPosition($scroll)
    .scrollTargetBehavior(FoldSettling(fold: pageHeight, inset: geometry.inset))
    .onScrollGeometryChange(for: FoldGeometry.self) {
      FoldGeometry(
        offset: $0.contentOffset.y + $0.contentInsets.top, inset: $0.contentInsets.top,
        visibleHeight: $0.containerSize.height)
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
    .sensoryFeedback(.impact, trigger: isOpen)
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
          Text(InvitationsModel.invitesToggle)
            .font(.subheadline.weight(.semibold))
          Image(systemName: "chevron.down")
            .font(.footnote.weight(.semibold))
        }
        .accentRow()
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .opacity(opacity)
    }
    .frame(maxWidth: .infinity)
    .padding([.horizontal, .top])
    .padding(.bottom, 8)
  }

  private func invitations(isOpen: Bool) -> some View {
    VStack(spacing: 16) {
      Button(action: close) {
        VStack(spacing: 6) {
          Image(systemName: "chevron.up")
            .font(.footnote.weight(.semibold))
            .accentRow()
          // Where the code ends up as the icon.
          Color.clear
            .frame(width: Self.iconSide, height: Self.iconSide)
            .onGeometryChange(for: CGRect.self) {
              $0.frame(in: .inviteQRFold)
            } action: {
              iconFrame = $0
            }
        }
        .padding(.horizontal, 24)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(InvitationsModel.showQRCode)
      .allowsHitTesting(isOpen)
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

  /// The code, moving from its place in the page to the icon's as the pane scrolls, crossing to
  /// the symbol over the last stretch.
  private func code(progress: Double) -> some View {
    let frame = Self.interpolate(codeFrame, iconFrame, progress)
    let symbol = min(max((progress - 0.6) / 0.4, 0), 1)
    return ZStack {
      InviteQRCode(address: address.absoluteString, label: InvitationsModel.qrLabel)
        .opacity(1 - symbol)
        .accessibilityHidden(progress >= 0.5)
      Image(systemName: "qrcode")
        .resizable()
        .scaledToFit()
        .foregroundStyle(Color.accentText)
        .opacity(symbol)
        .accessibilityHidden(true)
    }
    .frame(width: frame.width, height: frame.height)
    .offset(x: frame.minX, y: frame.minY)
    .allowsHitTesting(false)
  }

  private func open() {
    withAnimation(.smooth) { scroll.scrollTo(y: pageHeight - geometry.inset) }
  }

  private func close() {
    withAnimation(.smooth) { scroll.scrollTo(edge: .top) }
  }

  private static func interpolate(_ from: CGRect, _ to: CGRect, _ share: Double) -> CGRect {
    let mix = { (a: Double, b: Double) in a + (b - a) * share }
    return CGRect(
      x: mix(from.minX, to.minX), y: mix(from.minY, to.minY),
      width: mix(from.width, to.width), height: mix(from.height, to.height))
  }
}

/// The fold's scroll, counted from the top of the content rather than from the scroll view's own
/// origin, which sits the top bar's inset above it.
private struct FoldGeometry: Equatable {
  var offset = 0.0
  var inset = 0.0
  var visibleHeight = 0.0
}

/// Rests a scroll on the QR code or on the invitations, never between them.
private struct FoldSettling: ScrollTargetBehavior {
  let fold: Double
  let inset: Double

  func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
    guard fold > 0 else { return }
    let resting = InviteQRPaneScroll.restingOffset(
      start: context.originalTarget.rect.minY + inset, proposed: target.rect.minY + inset,
      fold: fold)
    target.rect.origin.y = resting - inset
  }
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
