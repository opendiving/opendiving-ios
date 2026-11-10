import Foundation

/// A person's page (`PersonDetailPageContent`): their name with the linked account's username
/// under it, their email and phone opening Mail and the dialler, and their notes.
public enum PersonPageContent {
  /// A way to reach the person: what the page shows, and the link it opens.
  public struct Reach: Hashable, Sendable {
    public let text: String
    /// Nil where the value makes no link, which then shows as text alone.
    public let url: URL?
  }

  /// The head: the name and the linked account's current username, nothing else of theirs.
  public static func hero(_ person: PersonRead) -> HeroContent {
    HeroContent(title: person.name, facts: username(person).map { [Fact(text: $0)] } ?? [])
  }

  /// `@ana`, where the person is linked to an account.
  public static func username(_ person: PersonRead) -> String? {
    shown(person.username).map { "@" + $0 }
  }

  /// The email, as a `mailto:` link.
  public static func email(_ person: PersonRead) -> Reach? {
    shown(person.email).map { Reach(text: $0, url: mailURL($0)) }
  }

  /// The phone, as a `tel:` link of its digits and `+`, as the web dials it.
  public static func phone(_ person: PersonRead) -> Reach? {
    shown(person.phone).map { phone in
      let digits = DiveDetailText.dialable(phone)
      return Reach(text: phone, url: digits.isEmpty ? nil : URL(string: "tel:" + digits))
    }
  }

  /// The page's *Notes*, where it has any.
  public static func notes(_ person: PersonRead) -> String? {
    person.notes.isEmpty ? nil : person.notes
  }

  private static func mailURL(_ email: String) -> URL? {
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = email
    return components.url
  }

  private static func shown(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    return value
  }
}
