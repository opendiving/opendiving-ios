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
    return PersonCreate(
      name: name.trimmedOfWhitespace, email: FormText.trimmedOrNil(email),
      phone: FormText.trimmedOrNil(phone), notes: notes, username: linkedUsername)
  }
}

extension PersonFormValues: RewritesLocalRefs {
  /// A person names no other record.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {}
}
