import Foundation

/// The check-in details as the screen edits them: text as typed, a blank meaning not set, and
/// the two lists as rows. ``update(for:)`` turns one group back into what the API stores.
public struct CheckinDetailsDraft: Hashable, Sendable {
  public var email = ""
  public var phone = ""
  public var dateOfBirth: CalendarDate?
  /// In call order: the first is called first.
  public var emergencyContacts: [Contact] = []
  public var insurancePolicies: [Policy] = []

  public struct Contact: Hashable, Sendable, Identifiable {
    public let id: UUID
    public var name = ""
    public var phone = ""
    public var relationship = ""

    public init(id: UUID = UUID(), name: String = "", phone: String = "", relationship: String = "")
    {
      self.id = id
      self.name = name
      self.phone = phone
      self.relationship = relationship
    }
  }

  public struct Policy: Hashable, Sendable, Identifiable {
    public let id: UUID
    public var provider = ""
    public var number = ""
    public var expiresOn: CalendarDate?

    public init(
      id: UUID = UUID(), provider: String = "", number: String = "",
      expiresOn: CalendarDate? = nil
    ) {
      self.id = id
      self.provider = provider
      self.number = number
      self.expiresOn = expiresOn
    }
  }

  /// The API's bounds, `CheckinDetailsUpdate`'s, which are DiveJSON's for each member.
  public static let maxEmergencyContacts = 5
  public static let maxInsurancePolicies = 5
  static let emailMax = 255
  static let phoneMax = 32
  static let nameMax = 255
  static let shortTextMax = 64

  public init() {}

  public init(_ details: CheckinDetailsRead) {
    for group in CheckinGroup.allCases { reset(group, to: details) }
  }

  /// Puts `group`'s members back as `details` holds them, leaving the other groups as typed.
  public mutating func reset(_ group: CheckinGroup, to details: CheckinDetailsRead) {
    switch group {
    case .about:
      email = details.email ?? ""
      phone = details.phone ?? ""
      dateOfBirth = details.dateOfBirth
    case .insurance:
      insurancePolicies = details.insurancePolicies.map {
        Policy(provider: $0.provider, number: $0.number ?? "", expiresOn: $0.expiresOn)
      }
    case .emergency:
      emergencyContacts = details.emergencyContacts.map {
        Contact(name: $0.name, phone: $0.phone ?? "", relationship: $0.relationship ?? "")
      }
    }
  }

  /// The body saving `group`: its members and no others, trimmed, a blank sent as null so an
  /// emptied member is cleared, and a list whole.
  public func update(for group: CheckinGroup) -> CheckinDetailsUpdate {
    switch group {
    case .about:
      CheckinDetailsUpdate(
        email: Self.patch(email), phone: Self.patch(phone),
        dateOfBirth: dateOfBirth.map(Patch.value) ?? .null)
    case .insurance:
      CheckinDetailsUpdate(
        insurancePolicies: insurancePolicies.map {
          InsurancePolicyWrite(
            provider: Self.trimmed($0.provider), number: Self.orNil($0.number),
            expiresOn: $0.expiresOn)
        })
    case .emergency:
      CheckinDetailsUpdate(
        emergencyContacts: emergencyContacts.map {
          EmergencyContactWrite(
            name: Self.trimmed($0.name), phone: Self.orNil($0.phone),
            relationship: Self.orNil($0.relationship))
        })
    }
  }

  /// What the API would refuse in `group`, by box, in the web's words. Lengths are counted
  /// after trimming and in code points, as the API counts them.
  public func problems(for group: CheckinGroup, today: CalendarDate) -> [CheckinField: String] {
    var found: [CheckinField: String] = [:]
    func tooLong(_ text: String, _ max: Int, _ label: String, _ field: CheckinField) {
      if Self.trimmed(text).unicodeScalars.count > max {
        found[field] = "\(label) cannot exceed \(max) characters"
      }
    }
    switch group {
    case .about:
      tooLong(email, Self.emailMax, "Email", .email)
      if found[.email] == nil, !Self.trimmed(email).isEmpty, !Self.looksLikeEmail(email) {
        found[.email] = "Please enter a valid email address"
      }
      tooLong(phone, Self.phoneMax, "Phone number", .phone)
      if let dateOfBirth, dateOfBirth > today {
        found[.dateOfBirth] = "Date of birth cannot be in the future"
      }
    case .insurance:
      for policy in insurancePolicies {
        if Self.trimmed(policy.provider).isEmpty {
          found[.policyProvider(policy.id)] = "Enter the provider"
        }
        tooLong(policy.provider, Self.nameMax, "Provider", .policyProvider(policy.id))
        tooLong(policy.number, Self.shortTextMax, "Policy number", .policyNumber(policy.id))
      }
    case .emergency:
      for contact in emergencyContacts {
        if Self.trimmed(contact.name).isEmpty {
          found[.contactName(contact.id)] = "Enter who to call"
        }
        tooLong(contact.name, Self.nameMax, "Name", .contactName(contact.id))
        tooLong(contact.phone, Self.phoneMax, "Phone number", .contactPhone(contact.id))
        tooLong(
          contact.relationship, Self.shortTextMax, "Relationship",
          .contactRelationship(contact.id))
      }
    }
    return found
  }

  /// Whether the box already holds `address`, as the web compares them.
  public func emailIs(_ address: String) -> Bool {
    Self.trimmed(email).lowercased() == address.lowercased()
  }

  private static func trimmed(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func orNil(_ text: String) -> String? {
    let text = trimmed(text)
    return text.isEmpty ? nil : text
  }

  private static func patch(_ text: String) -> Patch<String> {
    orNil(text).map(Patch.value) ?? .null
  }

  /// A shape check only, catching a slip before the request; the API's check is the real one.
  private static func looksLikeEmail(_ text: String) -> Bool {
    trimmed(text).wholeMatch(of: /[^\s@]+@[^\s@]+\.[^\s@]+/) != nil
  }
}
