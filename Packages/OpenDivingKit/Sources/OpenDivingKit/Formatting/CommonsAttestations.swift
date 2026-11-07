/// What a proposer affirms, word for word: a copy of the API's `ATTESTATIONS`, as the web holds
/// one, shown beside the tick and sent back. The API refuses any other text, so a rewording there
/// breaks proposing here until the phone is rebuilt.
public enum CommonsAttestations {
  public static let newSite =
    "I am adding this dive site from my own diving. It is not copied from another database, app "
    + "or publication. I dedicate it to the public domain under CC0 1.0."
  public static let change =
    "I am proposing this change from my own diving. It is not copied from another database, app "
    + "or publication. I dedicate it to the public domain under CC0 1.0."

  /// The deed the dedication names, linked beside the tick.
  public static let deed = "https://creativecommons.org/publicdomain/zero/1.0/"

  /// The API's limit on a word for the reviewer.
  static let messageMax = 2000

  /// Why `message` cannot be sent, if it cannot.
  static func refusal(of message: String) -> String? {
    FormText.length(message, "A word for the reviewer", max: messageMax)
  }
}
