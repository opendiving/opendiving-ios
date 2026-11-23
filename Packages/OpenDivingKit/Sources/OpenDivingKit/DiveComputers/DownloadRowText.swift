/// The words of a download's row, the one line saying what its dive waits for
/// (``DownloadRow/Line``).
enum DownloadRowText {
  /// Being read from the computer, or on its way to the server.
  static let syncing = "Syncing"
  /// Still on the computer, after the dive being read.
  static let waiting = "Waiting"
  static let waitingForInternet = "Waiting for internet"
  static let waitingForSignIn = "Waiting for sign-in"
  /// The time zone's question, or the computers' order.
  static let waitingForAnswer = "Waiting for your answer"
  static let couldNotImport = "Could not import"
}
