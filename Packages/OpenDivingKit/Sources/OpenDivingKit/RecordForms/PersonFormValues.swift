/// The *New Person* dialog's values and rules (`personSchema`).
public struct PersonFormValues: Codable, Hashable, Sendable {
  public var name: String
  public var email: String
  public var phone: String
  public var links: [WebLinkRow]
  public var notes: String

  /// `name` is what was typed into the picker before *Add*.
  public init(
    name: String = "", email: String = "", phone: String = "", links: [WebLinkRow] = [],
    notes: String = ""
  ) {
    self.name = name
    self.email = email
    self.phone = phone
    self.links = links
    self.notes = notes
  }

  public var issues: [FormIssue] {
    var list = FormIssueList()
    list.add("name", FormText.requiredName(name, "Name", max: 255))
    list.add("email", RecordFormRules.optionalEmail(email))
    list.add("phone", FormText.length(phone, "Phone", max: 32))
    WebLinkRow.check(links, into: &list)
    list.add("notes", FormText.length(notes, "Notes", max: DiveFormBounds.notesMax))
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
      phone: FormText.trimmedOrNil(phone), links: WebLinkRow.sent(links),
      notes: notes)
  }
}

extension PersonFormValues {
  /// The form an edit opens on.
  public init(editing person: PersonRead) {
    self.init(
      name: person.name, email: person.email ?? "", phone: person.phone ?? "",
      links: WebLinkRow.rows(person.links), notes: person.notes)
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
    if now.links != before.links { update.links = now.links ?? [] }
    return update
  }

  /// These values with a queued update laid over.
  public func applying(_ update: PersonUpdate) -> PersonFormValues {
    var next = self
    if let name = update.name { next.name = name }
    if let notes = update.notes { next.notes = notes }
    next.email = update.email.applied(to: email) ?? ""
    next.phone = update.phone.applied(to: phone) ?? ""
    if let links = update.links { next.links = WebLinkRow.rows(links) }
    return next
  }
}

extension PersonFormValues: RewritesLocalRefs {
  /// A person names no other record.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {}
}
