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

  private var hasAddress: Bool { addressParts.contains { !$0.trimmedOfWhitespace.isEmpty } }

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

extension ContactFormValues: RewritesLocalRefs {
  /// A contact names no other record.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {}
}
