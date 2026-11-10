/// The *New Person* dialog's values and rules (`personSchema`).
public struct PersonFormValues: Codable, Hashable, Sendable {
  public var name: String
  /// An account on this server, by its exact username; a copied `@` is taken off.
  public var username: String
  public var email: String
  public var phone: String
  public var notes: String

  /// `name` is what was typed into the picker before *Add*.
  public init(
    name: String = "", username: String = "", email: String = "", phone: String = "",
    notes: String = ""
  ) {
    self.name = name
    self.username = username
    self.email = email
    self.phone = phone
    self.notes = notes
  }

  /// The username as the API is asked for it: trimmed, without the `@` the pickers print, nil
  /// when empty (`normalizeLinkedUsername`).
  var linkedUsername: String? {
    var text = username.trimmedOfWhitespace
    if text.hasPrefix("@") { text.removeFirst() }
    return FormText.trimmedOrNil(text)
  }

  public var issues: [FormIssue] {
    var list = FormIssueList()
    list.add("name", FormText.requiredName(name, "Name", max: 255))
    list.add("email", RecordFormRules.optionalEmail(email))
    list.add("phone", FormText.length(phone, "Phone", max: 32))
    list.add("notes", FormText.length(notes, "Notes", max: DiveFormBounds.notesMax))
    if (linkedUsername ?? "").utf16.count > 20 {
      list.add("username", FormText.tooLong("Username", 20))
    }
    return list.issues
  }

  /// `POST /person`'s body: every box trimmed, a blank one left out.
  public func toCreate() throws(FormInvalid) -> PersonCreate {
    if !issues.isEmpty { throw FormInvalid(issues: issues) }
    return written
  }

  private var written: PersonCreate {
    PersonCreate(
      name: name.trimmedOfWhitespace, email: FormText.trimmedOrNil(email),
      phone: FormText.trimmedOrNil(phone), notes: notes, username: linkedUsername)
  }
}

extension PersonFormValues {
  /// The form an edit opens on.
  public init(editing person: PersonRead) {
    self.init(
      name: person.name, username: person.username ?? "", email: person.email ?? "",
      phone: person.phone ?? "", notes: person.notes)
  }

  /// `PATCH /person/{uuid}`'s body: what differs from the values the form opened on.
  public func diff(from baseline: PersonFormValues) throws(FormInvalid) -> PersonUpdate {
    let now = try toCreate()
    let before = baseline.written
    var update = PersonUpdate()
    if now.name != before.name { update.name = now.name }
    if now.notes != before.notes { update.notes = now.notes }
    update.email = .change(from: before.email, to: now.email)
    update.phone = .change(from: before.phone, to: now.phone)
    update.username = .change(from: before.username, to: now.username)
    return update
  }

  /// These values with a queued update laid over.
  public func applying(_ update: PersonUpdate) -> PersonFormValues {
    var next = self
    if let name = update.name { next.name = name }
    if let notes = update.notes { next.notes = notes }
    next.email = update.email.applied(to: email) ?? ""
    next.phone = update.phone.applied(to: phone) ?? ""
    next.username = update.username.applied(to: username) ?? ""
    return next
  }
}

extension PersonFormValues: RewritesLocalRefs {
  /// A person names no other record.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {}
}
