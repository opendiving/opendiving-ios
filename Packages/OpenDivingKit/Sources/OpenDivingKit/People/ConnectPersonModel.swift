import Foundation
import Observation

/// The person form opened from *Added you* or by somebody's connect link: headed by the account
/// it connects to, it either makes a person connected to that account or connects one of the
/// diver's people who is not connected yet, opening on the one named as the account is named. A
/// direct call, online only, since it needs the account's tie to the diver to stand: a refusal is
/// the API's sentence on the form.
@MainActor
@Observable
public final class ConnectPersonModel {
  public enum Choice: Hashable, Sendable {
    case new
    case existing(UUID)
  }

  /// The account the person is connected to, and how the server is told which it is.
  public enum Connection: Hashable, Sendable {
    /// A row under *Added you*, by the account's public id.
    case account(AddedYouRow)
    /// A connect link's owner, by the link's token.
    case link(token: String, owner: ConnectLinkOwnerForYou)
  }

  public let connection: Connection
  /// The diver's people who are not connected to any account, by name.
  public let candidates: [PersonRead]
  public var choice: Choice
  /// A new person's fields, the name filled in with the account's.
  public var values: PersonFormValues
  public private(set) var attempted = false
  public private(set) var isSaving = false
  /// Why the last save did not land.
  public private(set) var failure: String?

  @ObservationIgnored private let session: Session
  /// Kept across tries, so a create retried after a lost reply is the same request.
  @ObservationIgnored private let idempotencyKey = UUID()

  public convenience init(session: Session, account: AddedYouRow) {
    self.init(session: session, connection: .account(account))
  }

  public init(session: Session, connection: Connection) {
    self.session = session
    self.connection = connection
    candidates = Self.candidates(Array(session.people.values))
    values = PersonFormValues(name: connection.name)
    choice = Self.opening(named: connection.name, among: candidates)
  }

  nonisolated static func candidates(_ people: [PersonRead]) -> [PersonRead] {
    people.filter { $0.username == nil }
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  /// The person named as the account is, where the diver has one, else a new person.
  nonisolated static func opening(named account: String, among candidates: [PersonRead]) -> Choice {
    let name = account.trimmedOfWhitespace.lowercased()
    return candidates.first { $0.name.trimmedOfWhitespace.lowercased() == name }
      .map { .existing($0.uuid) } ?? .new
  }

  public var issues: [FormIssue] { attempted && choice == .new ? values.issues : [] }

  /// The sentence under one field, once a save has been tried.
  public func message(_ field: String) -> String? {
    issues.first { $0.field == field }?.message
  }

  /// What saving shows the other diver.
  public var reveals: String {
    "Saving shows \(connection.name) your name, username and picture."
  }

  /// Makes or connects the person; true once the server has it.
  public func save() async -> Bool {
    guard !isSaving else { return false }
    attempted = true
    failure = nil
    var create: PersonCreate?
    if choice == .new {
      guard var body = try? values.toCreate() else { return false }
      switch connection {
      case .account(let row): body.connectAccount = row.uuid
      case .link(let token, _): body.connectLink = token
      }
      create = body
    }
    isSaving = true
    defer { isSaving = false }
    do {
      let client = try session.routedClient()
      if let create {
        _ = try await client.createPerson(create, idempotencyKey: idempotencyKey)
      } else if case .existing(let uuid) = choice {
        try await client.updatePerson(uuid, connection.update)
      }
    } catch {
      failure = APIError(error).message
      return false
    }
    if let stores = AccountStores.current(session) {
      let hub = OutboxHub.hub(for: stores.directory)
      // The owner of a link may be under *Added you* too, by an id the link does not give: the
      // section reads again.
      if case .account(let row) = connection { hub.gone(row.uuid) }
      hub.changed()
      hub.listsChanged()
    }
    await session.refreshPeople()
    await LookupsModel.refresh(session)
    return true
  }
}

extension ConnectPersonModel.Connection {
  public var name: String {
    switch self {
    case .account(let row): row.name
    case .link(_, let owner): owner.name
    }
  }

  public var username: String {
    switch self {
    case .account(let row): row.username
    case .link(_, let owner): owner.username
    }
  }

  public var picture: ConnectedPicture? {
    switch self {
    case .account(let row): .of(row)
    case .link(let token, let owner): .of(owner, token: token)
    }
  }

  /// The body that connects one of the diver's people.
  var update: PersonUpdate {
    switch self {
    case .account(let row): PersonUpdate(connectAccount: row.uuid)
    case .link(let token, _): PersonUpdate(connectLink: token)
    }
  }
}
