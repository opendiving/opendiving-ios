import Foundation
import Observation

/// *Invitations*: the diver's invite link over the invitations they sent and the form that sends
/// another. Direct calls, online only; every refusal is the API's sentence as it is.
///
/// An instance anyone may join answers the list's read with 404, and the section is left out.
/// The link's own read answers 404 there too, so it is asked only once the list has answered:
/// from then on its 404 means the diver has no link yet. The link's token lives here alone — no
/// file, no keychain item — and is read again on every visit.
@MainActor
@Observable
public final class InvitationsModel {
  /// The web's page of invitations.
  nonisolated public static let pageSize = 20

  /// The invitations read so far, newest first, and where the paging stands.
  public struct Loaded: Hashable, Sendable {
    public var invitations: [InvitationRead]
    public var hasMore: Bool
    public var page: Int

    public init(invitations: [InvitationRead], hasMore: Bool, page: Int) {
      self.invitations = invitations
      self.hasMore = hasMore
      self.page = page
    }
  }

  /// What the link block asks the diver to confirm.
  public enum LinkChange: Hashable, Sendable {
    case reset, remove
  }

  public let list: OptionalList<Loaded>

  /// The diver's link, once ``isLinkRead``; nil there means there is none yet.
  public private(set) var link: InviteLinkRead?
  /// A read of the link has landed.
  public private(set) var isLinkRead = false
  /// Why the last read of the link failed.
  public private(set) var linkLoadFailure: String?
  /// The change waiting for the diver to confirm it.
  public var confirmingLink: LinkChange?
  public private(set) var isChangingLink = false
  /// Why the last create, reset or removal failed.
  public private(set) var linkFailure: String?

  /// The address to invite.
  public var email = ""
  /// What is wrong with ``email``, once a send has been tried with it.
  public private(set) var emailError: String?
  public private(set) var isSending = false
  /// Why the last send invited nobody: the API's sentence.
  public private(set) var sendFailure: String?
  /// What the last send did, until the next.
  public private(set) var sentNote: String?

  public private(set) var isLoadingMore = false
  /// Why the last *Show older invitations* read nothing.
  public private(set) var loadMoreFailure: String?

  /// The invitation waiting for the diver to confirm its revocation.
  public var confirmingRevoke: InvitationRead?
  public private(set) var revoking: UUID?
  /// Why the last revocation failed.
  public private(set) var revokeFailure: String?

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    list = OptionalList(session: session) { client in
      let page = try await client.invitations(page: 1, itemsPerPage: Self.pageSize)
      return Loaded(invitations: page.data, hasMore: page.hasMore, page: page.page)
    }
  }

  /// Reads the list, then the link once the list says the feature is here.
  public func load() async {
    await list.load()
    guard list.value != nil else { return }
    await loadLink()
  }

  /// Reads again each time a route appears, until the calling task is cancelled.
  public func followRoute() async {
    await session.connectivity.eachRouteAppearance { await load() }
  }

  public func loadLink() async {
    do {
      link = try await session.routedClient().inviteLink()
      isLinkRead = true
      linkLoadFailure = nil
    } catch is CancellationError {
    } catch {
      linkLoadFailure = APIError(error).message
    }
  }

  // MARK: - The link

  /// The address the link opens, on the server's own origin, where the web serves `/join`.
  public var linkAddress: URL? {
    guard let link, let origin = session.state.origin else { return nil }
    return Self.address(token: link.token, on: origin)
  }

  nonisolated public static func address(token: String, on origin: ServerOrigin) -> URL {
    var components = URLComponents(url: origin.url, resolvingAgainstBaseURL: false)!
    components.path = "/join"
    components.queryItems = [URLQueryItem(name: "via", value: token)]
    // Built from an origin and a query item, which always form a URL.
    return components.url!
  }

  /// The share sheet's title: the invitation email's own subject.
  public var shareTitle: String { Self.shareTitle(name: session.user?.name) }

  nonisolated public static func shareTitle(name: String?) -> String {
    "\(name ?? "A diver") invited you to OpenDiving"
  }

  /// Makes the link, or resets it once ``confirmingLink`` asked to.
  public func createLink() async {
    guard !isChangingLink else { return }
    confirmingLink = nil
    linkFailure = nil
    isChangingLink = true
    defer { isChangingLink = false }
    do {
      link = try await session.routedClient().createInviteLink()
      isLinkRead = true
    } catch {
      linkFailure = APIError(error).message
    }
  }

  /// Carries out ``confirmingLink``.
  public func confirmLinkChange() async {
    switch confirmingLink {
    case .reset: await createLink()
    case .remove: await removeLink()
    case nil: break
    }
  }

  private func removeLink() async {
    guard !isChangingLink else { return }
    confirmingLink = nil
    linkFailure = nil
    isChangingLink = true
    defer { isChangingLink = false }
    do {
      try await session.routedClient().removeInviteLink()
      link = nil
    } catch {
      linkFailure = APIError(error).message
    }
  }

  // MARK: - Sending

  public func send() async {
    guard !isSending else { return }
    let address = email.trimmedOfWhitespace
    emailError = RecordFormRules.isEmail(address) ? nil : "Please enter a valid email address"
    sendFailure = nil
    sentNote = nil
    guard emailError == nil else { return }
    isSending = true
    defer { isSending = false }
    let created: InvitationRead
    do {
      created = try await session.routedClient().sendInvitation(InvitationCreate(email: address))
    } catch {
      sendFailure = APIError(error).message
      return
    }
    // Prepended from the answer rather than read again: the list is newest first.
    list.update { Self.prepending(created, to: $0) }
    email = ""
    sentNote = "\(created.email ?? address) can now create an account here."
  }

  // MARK: - Paging

  public var canLoadMore: Bool { list.value?.hasMore == true && !isLoadingMore }

  /// *Show older invitations*: the next page, after what is shown.
  public func loadMore() async {
    guard let loaded = list.value, loaded.hasMore, !isLoadingMore else { return }
    isLoadingMore = true
    loadMoreFailure = nil
    defer { isLoadingMore = false }
    do {
      let page = try await session.routedClient().invitations(
        page: loaded.page + 1, itemsPerPage: Self.pageSize)
      list.update { Self.appending(page, to: $0) }
    } catch {
      loadMoreFailure = APIError(error).message
    }
  }

  nonisolated static func prepending(_ invitation: InvitationRead, to loaded: Loaded) -> Loaded {
    var loaded = loaded
    loaded.invitations =
      [invitation] + loaded.invitations.filter { $0.uuid != invitation.uuid }
    return loaded
  }

  /// The route pages by offset over a newest-first order, so every invitation made since the
  /// first page was read — a send here, one from the web or the operator's queue — shifts the
  /// next page down and repeats a row already shown. Dropping what is known by uuid is what
  /// keeps each invitation to one row.
  nonisolated static func appending(
    _ page: PaginatedListResponse<InvitationRead>, to loaded: Loaded
  ) -> Loaded {
    var loaded = loaded
    let known = Set(loaded.invitations.map(\.uuid))
    loaded.invitations += page.data.filter { !known.contains($0.uuid) }
    loaded.hasMore = page.hasMore
    loaded.page = page.page
    return loaded
  }

  // MARK: - Revoking

  /// Revokes ``confirmingRevoke``, then reads the list again for the server's stamp.
  public func confirmRevoke() async {
    guard let invitation = confirmingRevoke, revoking == nil else { return }
    confirmingRevoke = nil
    revokeFailure = nil
    revoking = invitation.uuid
    defer { revoking = nil }
    do {
      try await session.routedClient().revokeInvitation(invitation.uuid)
    } catch {
      revokeFailure = APIError(error).message
      return
    }
    await list.load()
  }

  // MARK: - What the section says

  public static let description =
    "New accounts on this instance are by invitation. Invite someone and they can sign in with"
    + " that address to create their own account."
  public static let openInstance =
    "Anyone can create an account on this copy of OpenDiving, so there is nobody to invite."
  public static let loadFailed = "Couldn't load the invitations you have sent."
  public static let empty = "You have not invited anyone yet."
  public static let sendButton = "Send invitation"
  public static let emailPlaceholder = "buddy@example.com"
  public static let showOlder = "Show older invitations"
  nonisolated public static let pending = "Pending"
  nonisolated public static let revoked = "Revoked"
  public static let revokeTitle = "Revoke this invitation"
  public static let revokeButton = "Revoke"

  public static func revokeMessage(_ invitation: InvitationRead) -> String {
    "\(invitation.email ?? "That address") will no longer be able to create an account here. The"
      + " row stays in this list as revoked, and you can invite the address again later."
  }

  public static let linkLoadFailed = "Couldn't load your invite link."
  public static let linkNone =
    "A link of your own lets whoever follows it create an account here as your invitation,"
    + " within the same allowance as the invitations you send. Show it as a QR code, or send it."
  public static let linkCreate = "Create your invite link"
  public static let linkLive =
    "Whoever scans or follows this link can create an account here, counted as your invitation."
    + " You will see the name on their account, never their address. It keeps working until"
    + " you reset or remove it."
  public static let linkAddressLabel = "Invite link address"
  public static let linkCopied = "Link copied"
  public static let qrLabel = "QR code of your invite link"
  public static let resetTitle = "Reset your invite link"
  public static let resetMessage =
    "The link you have now stops working for anyone who has it, and a new link and QR code take"
    + " its place. People who already joined through it stay on your list."
  public static let resetButton = "Reset"
  public static let removeTitle = "Remove your invite link"
  public static let removeMessage =
    "The link stops working for anyone who has it. People who already joined through it stay on"
    + " your list, and you can make a new link later."
  public static let removeButton = "Remove"

  /// A row's first line: the address, or who joined through the link.
  nonisolated public static func title(_ invitation: InvitationRead) -> String {
    if invitation.fromInviteLink {
      return "\(invitation.memberName ?? "Someone") joined through your link"
    }
    return invitation.email ?? ""
  }

  /// A typed row's mark: `Accepted Oct 1, 2026`, `Revoked` or `Pending`. A link row has none.
  nonisolated public static func badge(
    _ invitation: InvitationRead, in timeZone: TimeZone = .current
  ) -> String? {
    guard !invitation.fromInviteLink else { return nil }
    if let accepted = invitation.acceptedAt {
      return "Accepted " + PasskeysModel.day(accepted, timeZone)
    }
    return invitation.revokedAt == nil ? pending : revoked
  }

  /// A row's second line, by the day alone: `Invited Oct 1, 2026`, or the day a link sign-up
  /// joined.
  nonisolated public static func details(
    _ invitation: InvitationRead, in timeZone: TimeZone = .current
  ) -> String {
    if invitation.fromInviteLink {
      return PasskeysModel.day(invitation.acceptedAt ?? invitation.createdAt, timeZone)
    }
    return "Invited " + PasskeysModel.day(invitation.createdAt, timeZone)
  }

  /// Only a typed row that could still be used can be revoked.
  nonisolated public static func canRevoke(_ invitation: InvitationRead) -> Bool {
    !invitation.fromInviteLink && invitation.isPending
  }
}
