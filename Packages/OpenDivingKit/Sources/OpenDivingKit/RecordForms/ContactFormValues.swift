import Foundation

/// The *New Contact* dialog's values and rules (`contactSchema`): a dive centre, a school, a
/// shop, a place to stay. The coordinates are text as typed; every address part is a box.
public struct ContactFormValues: Codable, Hashable, Sendable {
  public var name: String
  /// Role keys, in the order ticked.
  public var roles: [String]
  public var phone: String
  public var email: String
  /// A bare host gets `https://` in front when sent.
  public var website: String
  public var street: String
  public var city: String
  public var postcode: String
  public var region: String
  public var country: String
  public var latitude: String
  public var longitude: String
  public var notes: String

  /// `roles` is the host's suggestion — the dive form's dive-centre picker opens it with
  /// ``diveCenterRoles`` — and `name` what was typed into the picker before *Add*.
  public init(
    name: String = "", roles: [String] = [], phone: String = "", email: String = "",
    website: String = "", street: String = "", city: String = "", postcode: String = "",
    region: String = "", country: String = "", latitude: String = "", longitude: String = "",
    notes: String = ""
  ) {
    self.name = name
    self.roles = roles
    self.phone = phone
    self.email = email
    self.website = website
    self.street = street
    self.city = city
    self.postcode = postcode
    self.region = region
    self.country = country
    self.latitude = latitude
    self.longitude = longitude
    self.notes = notes
  }

  /// The roles a contact created from a dive's dive-centre picker starts with.
  public static let diveCenterRoles = ["dive_center"]

  /// The website as sent: an absolute URL, `https://` put before a bare host, nil for an empty
  /// box (`normalizeWebsite`).
  var normalizedWebsite: String? {
    guard let trimmed = FormText.trimmedOrNil(website) else { return nil }
    return Self.hasScheme(trimmed) ? trimmed : "https://" + trimmed
  }

  private static func hasScheme(_ text: String) -> Bool {
    guard let colon = text.range(of: "://") else { return false }
    let scheme = text[..<colon.lowerBound]
    guard let first = scheme.first, first.isASCII, first.isLetter else { return false }
    return scheme.allSatisfy { $0.isASCIILetterOrDigit || "+.-".contains($0) }
  }

  /// The API's own check: an http or https scheme and a host, on what is sent.
  private var isWebsite: Bool {
    guard let website = normalizedWebsite else { return true }
    guard website.utf16.count <= 512, let parts = URLComponents(string: website),
      let scheme = parts.scheme?.lowercased(), scheme == "http" || scheme == "https",
      let host = parts.host, !host.isEmpty
    else { return false }
    return true
  }

  private var addressParts: [String] { [street, city, postcode, region, country] }

  /// Whether any part of an address is filled, which makes the country required.
  public var hasAddress: Bool { addressParts.contains { !$0.trimmedOfWhitespace.isEmpty } }

  public var issues: [FormIssue] {
    var list = FormIssueList()
    list.add("name", FormText.requiredName(name, "Name", max: 255))
    list.add("phone", FormText.length(phone, "Phone", max: 32))
    list.add("email", RecordFormRules.optionalEmail(email))
    list.add("address", member: "street", FormText.length(street, "Address", max: 255))
    list.add("address", member: "city", FormText.length(city, "City", max: 255))
    list.add("address", member: "postcode", FormText.length(postcode, "Postcode", max: 32))
    list.add("address", member: "region", FormText.length(region, "Region", max: 255))
    list.add("address", member: "country", FormText.length(country, "Country", max: 255))
    list.add("notes", FormText.length(notes, "Notes", max: DiveFormBounds.notesMax))
    if !isWebsite { list.add("website", "Use a web address, e.g. blueocean.com") }
    if hasAddress && country.trimmedOfWhitespace.isEmpty {
      list.add("address", member: "country", "An address needs its country")
    }
    CoordinateEntry.check(latitude: latitude, longitude: longitude, into: &list)
    return list.issues
  }

  /// `POST /contact`'s body: each box trimmed and a blank one left out, the address whole or
  /// not at all.
  public func toCreate() throws(FormInvalid) -> ContactCreate {
    if !issues.isEmpty { throw FormInvalid(issues: issues) }
    return written
  }

  private var written: ContactCreate {
    let address =
      hasAddress
      ? ContactAddressWrite(
        street: FormText.trimmedOrNil(street), city: FormText.trimmedOrNil(city),
        postcode: FormText.trimmedOrNil(postcode), region: FormText.trimmedOrNil(region),
        country: country.trimmedOfWhitespace)
      : nil
    return ContactCreate(
      name: name.trimmedOfWhitespace, phone: FormText.trimmedOrNil(phone),
      latitude: CoordinateEntry.value(latitude), longitude: CoordinateEntry.value(longitude),
      notes: notes, roles: roles, email: FormText.trimmedOrNil(email), website: normalizedWebsite,
      address: address)
  }
}

extension ContactFormValues {
  /// The form an edit opens on.
  public init(editing contact: ContactRead) {
    let address = contact.address
    self.init(
      name: contact.name, roles: contact.roles, phone: contact.phone ?? "",
      email: contact.email ?? "", website: contact.website ?? "",
      street: address?.street ?? "", city: address?.city ?? "",
      postcode: address?.postcode ?? "", region: address?.region ?? "",
      country: address?.country ?? "", latitude: CoordinateEntry.text(contact.latitude),
      longitude: CoordinateEntry.text(contact.longitude), notes: contact.notes)
  }

  /// `PATCH /contact/{uuid}`'s body: what differs from the values the form opened on. The
  /// position goes as a pair and the address whole, as the API takes each.
  public func diff(from baseline: ContactFormValues) throws(FormInvalid) -> ContactUpdate {
    let now = try toCreate()
    let before = baseline.written
    var update = ContactUpdate()
    if now.name != before.name { update.name = now.name }
    if now.roles != before.roles { update.roles = now.roles }
    if now.notes != before.notes { update.notes = now.notes }
    update.phone = .change(from: before.phone, to: now.phone)
    update.email = .change(from: before.email, to: now.email)
    update.website = .change(from: before.website, to: now.website)
    update.address = .change(from: before.address, to: now.address)
    if now.latitude != before.latitude || now.longitude != before.longitude {
      update.latitude = now.latitude.map(Patch.value) ?? .null
      update.longitude = now.longitude.map(Patch.value) ?? .null
    }
    return update
  }

  /// These values with a queued update laid over.
  public func applying(_ update: ContactUpdate) -> ContactFormValues {
    var next = self
    if let name = update.name { next.name = name }
    if let roles = update.roles { next.roles = roles }
    if let notes = update.notes { next.notes = notes }
    next.phone = update.phone.applied(to: phone) ?? ""
    next.email = update.email.applied(to: email) ?? ""
    next.website = update.website.applied(to: website) ?? ""
    if update.address != .absent {
      let address = update.address.applied(to: nil)
      next.street = address?.street ?? ""
      next.city = address?.city ?? ""
      next.postcode = address?.postcode ?? ""
      next.region = address?.region ?? ""
      next.country = address?.country ?? ""
    }
    if update.latitude != .absent {
      next.latitude = CoordinateEntry.text(update.latitude.applied(to: nil))
      next.longitude = CoordinateEntry.text(update.longitude.applied(to: nil))
    }
    return next
  }
}

extension ContactFormValues: RewritesLocalRefs {
  /// A contact names no other record.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {}
}
