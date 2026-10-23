import Foundation

extension PhotoCreditContent {
  /// The credit composed from the parts the API stores, as the web composes it. Nil with no
  /// photo, and when nothing at all was recorded beside one: a line reading *Photo* with
  /// nothing after it is worse than no line.
  public static func species(_ species: SpeciesRead) -> PhotoCreditContent? {
    guard species.photoSha256 != nil else { return nil }
    let author = present(species.photoAuthor)
    let license = present(species.photoLicense)
    let source = present(species.photoSourceUrl)
    guard author != nil || license != nil || source != nil else { return nil }

    var runs = [Run("Photo" + (author.map { " by \($0)" } ?? ""))]
    if let license {
      runs += [
        Run(" · "), Run(license, url: present(species.photoLicenseUrl).flatMap { URL(string: $0) }),
      ]
    }
    if let source {
      runs += [Run(" · "), Run("Wikimedia Commons", url: URL(string: source))]
    }
    return PhotoCreditContent(runs: runs)
  }

  /// The web tests each part by JavaScript's truthiness, which reads an empty string as absent.
  private static func present(_ part: String?) -> String? {
    guard let part, !part.isEmpty else { return nil }
    return part
  }
}
