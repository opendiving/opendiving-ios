import Foundation

/// The words of the *Dive Computers* screen, a computer's page and a download's notifications.
public enum DiveComputerText {
  public static let connect = "Connect a dive computer"
  /// Starts the search for a computer to pair.
  public static let pair = "Pair a dive computer"
  public static let screenTitle = "Dive Computers"
  public static let pairedHeading = "Paired Computers"
  /// Opens the import, for the files a computer's own app or desktop software saves.
  public static let importFiles = "Import files"
  public static let importFilesFooter =
    "Bring in the dives a dive computer's own app or desktop software has saved to a file."
  public static let scanningHeading = "Looking for Dive Computers"
  public static let scanningInstruction =
    "Wake your dive computer and turn on its Bluetooth, then keep it next to the phone."
  public static let bluetoothOff = "Bluetooth is off. Turn it on to find your dive computer."
  public static let bluetoothRefused =
    "This app is not allowed to use Bluetooth. Allow it in the Settings app to find your dive"
    + " computer."
  public static let openSettings = "Open Settings"
  public static let accountLoading =
    "Your account is still loading; connect the dive computer again in a moment."
  public static let lockHint = "You can lock the phone. The download keeps going."
  public static let downloadAll = "Download all dives"
  public static let noDives = "No dives on this computer."
  public static let timeZoneQuestion = "Which time zone were these dives in?"
  public static let connecting = "Connecting"
  /// Once the computer is identified, until the download starts.
  public static let reading = "Reading"

  // MARK: - The list

  /// *Last downloaded 12 October*: a computer's line once a download of it was kept.
  public static func lastDownloaded(_ day: Date, in zone: TimeZone = .current) -> String {
    "Last downloaded \(Self.day(day, in: zone))"
  }

  public static let noDivesYet = "No dives downloaded yet"
  public static let automaticOff = "Automatic download is off"
  public static let lastUnfinished = "The last download did not finish"
  public static let waitingUntilFree = "Waiting until this computer is free"
  public static let waitingToReconnect = "Waiting for this computer to reconnect"

  /// Under the list once more than one computer is paired.
  public static let orderFooter =
    "When more than one computer recorded a dive, the recording from the highest one in this list"
    + " is shown by default. Dives already in your logbook keep the recording they show."

  public static let orderQuestion = "Which computer comes first?"
  public static let orderQuestionDetail =
    "When both record the same dive, the recording from the first computer is shown by default."

  public static let allowNotifications = "Allow notifications"
  public static let notificationsSentence =
    "A notification tells you when new dives are in your logbook."

  // MARK: - A computer's downloads

  public static let downloadAutomatically = "Download automatically"
  public static let downloadAutomaticallyFooter =
    "The phone downloads new dives each time this computer connects, even when the phone is"
    + " locked. The dives are imported into your logbook without a review. This stops if you"
    + " swipe the app away, and it can stop after you turn Bluetooth off or use flight mode."
    + " Open the app to start it again."
  public static let downloadNew = "Download new dives"

  // MARK: - Forgetting

  public static let forget = "Forget this dive computer"
  public static let forgetMessage =
    "The next download from it, on any server, takes every dive again."

  /// *Forget Perdix 3?*
  public static func forgetTitle(_ record: DiveComputerRecord) -> String {
    "Forget \(record.product)?"
  }

  // MARK: - A computer's page

  public static let serialLabel = "Serial number"
  public static let hardwareLabel = "Hardware version"
  public static let firmwareLabel = "Firmware version"
  public static let lastDownloadedLabel = "Last downloaded"

  // MARK: - Waiting

  /// Asked before a download waiting to be imported is removed from the phone.
  public static let removeDownloadWarning =
    "These dives have not been imported. The next download takes them again only with Download"
    + " all dives."

  /// *3 dives waiting to upload*.
  public static func waitingToUpload(_ dives: Int) -> String {
    "\(count(dives)) waiting to upload"
  }

  /// *3 dives from Shearwater Perdix 3*: a download's row on *Waiting to Sync*.
  public static func fromComputer(_ dives: Int, _ computer: String) -> String {
    "\(count(dives)) from \(computer)"
  }

  /// A download's stage on *Waiting to Sync* while it waits to go up.
  public static let waitingToUploadStage = "Waiting to upload"

  /// Beneath a download that waits, what its last upload met, as a queued write's row says it:
  /// *Last try: the server answered 503*. `nil` is a failure that is not the API's.
  public static func lastTry(_ error: APIError?) -> String {
    switch error {
    case .http(let status, _)?: OutboxAnswer.status(status).sentence
    case .unreachable?: OutboxAnswer.unreachable.sentence
    case let error?: "Last try: \(error.message)"
    case nil: "Last try: the upload failed on this phone"
    }
  }

  /// A download kept because the server answered with an import to review.
  public static let needsNewerServer =
    "The app needs a server released after v0.7.0, one that applies an import in one request."

  /// *Choose a time zone to import 3 dives*.
  public static func chooseTimeZone(_ dives: Int) -> String {
    "Choose a time zone to import \(count(dives))"
  }

  // MARK: - Downloading

  /// *Downloading dive 3*.
  public static func downloading(_ dive: Int) -> String { "Downloading dive \(dive)" }

  /// *Downloading 2 of 3 new dives*.
  public static func downloading(_ dive: Int, of total: Int) -> String {
    "Downloading \(dive) of \(total) new " + (total == 1 ? "dive" : "dives")
  }

  /// While a download has dives to come and nothing yet to reckon their time by.
  public static let estimatingTimeLeft = "Estimating time left…"

  /// *About 4 minutes left*, *About 1 hour 10 minutes left*, *Less than a minute left*.
  public static func timeLeft(_ seconds: TimeInterval) -> String {
    guard seconds >= 60 else { return "Less than a minute left" }
    let minutes = Int((seconds / 60).rounded())
    func units(_ n: Int, _ unit: String) -> String { "\(n) \(unit)" + (n == 1 ? "" : "s") }
    guard minutes >= 60 else { return "About \(units(minutes, "minute")) left" }
    let rest = minutes % 60
    return "About \(units(minutes / 60, "hour"))" + (rest == 0 ? "" : " \(units(rest, "minute"))")
      + " left"
  }

  /// *No new dives since 12 October.*
  public static func nothingNew(since: Date, in zone: TimeZone = .current) -> String {
    "No new dives since \(day(since, in: zone))."
  }

  /// *11 dives on this computer*: the count, where the download sets no fingerprint.
  public static func onComputer(_ dives: Int) -> String {
    "\(count(dives)) on this computer"
  }

  /// *3 new dives out of 11 on this computer*: the count, where the download took up from a
  /// fingerprint.
  public static func newOnComputer(_ new: Int, of dives: Int) -> String {
    (new == 1 ? "1 new dive" : "\(new) new dives") + " out of \(dives) on this computer"
  }

  /// While the computer says it is busy with another app, which the phone cannot see, before any
  /// dive has downloaded.
  public static let busy = "This computer is busy. The download starts when it is free."

  /// While the computer says it is busy, once a dive has downloaded.
  public static let busyContinues =
    "This computer is busy. The download continues when it is free."

  /// Once another app's handshake broke a transfer, until a dive arrives: the computer never says
  /// it is free of such an app, so the line names what frees it instead.
  public static let busyOtherApp =
    "This computer is busy. Closing other apps that use it lets the download go on."

  /// While a walk waits for a computer that dropped the link, connecting or downloading.
  public static let linkLost =
    "The connection to this computer was lost. The download continues when it is back in range"
    + " with its Bluetooth on."

  /// *3 dives waiting to upload.*: every new dive was downloaded before and waits on the phone
  /// to be imported.
  public static func alreadyWaiting(_ dives: Int) -> String {
    waitingToUpload(dives) + "."
  }

  /// *1 dive couldn't be downloaded.*: entries whose download failed the same way each time.
  public static func couldNotDownload(_ dives: Int) -> String {
    "\(count(dives)) couldn't be downloaded."
  }

  /// A found or remembered computer's line beneath its name:
  /// *Serial D9772626 · Last downloaded 12 October*.
  public static func subtitle(serial: String?, lastDownloaded: Date?, in zone: TimeZone = .current)
    -> String?
  {
    var parts: [String] = []
    if let serial { parts.append("Serial \(serial)") }
    if let lastDownloaded { parts.append("Last downloaded \(day(lastDownloaded, in: zone))") }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  /// *3 dives downloaded.*, with the dives the parser could not read after it.
  public static func downloaded(_ dives: Int, refused: Int) -> String {
    var text = "\(count(dives)) downloaded."
    if refused > 0 { text += " " + couldNotRead(refused) }
    return text
  }

  /// *1 dive could not be read.*
  public static func couldNotRead(_ refused: Int) -> String {
    refused == 1 ? "1 dive could not be read." : "\(refused) dives could not be read."
  }

  /// A download that stopped on a failure, naming libdivecomputer's status.
  public static func failed(_ status: String) -> String {
    "The download stopped: \(status)."
  }

  public static let cancelled = "The download was cancelled."
  /// A connection that never opened. A computer forgotten in the Settings app keeps its side of
  /// the pairing until it is paired anew from the computer, and until then answers no connection.
  public static let unreachable =
    "The dive computer did not answer. Wake it and turn on its Bluetooth, then connect again."
    + " If you forgot it in the Settings app's Bluetooth list, start a new pairing from the dive"
    + " computer's own Bluetooth menu first."

  /// The archive could not be written on this phone.
  public static func notWritten(_ error: any Error) -> String {
    "The dives could not be kept on this phone: \(error)."
  }

  // MARK: - Pieces

  /// *Shearwater Perdix 3*.
  public static func title(vendor: String, product: String) -> String {
    let vendor = vendor.trimmingCharacters(in: .whitespaces)
    let product = product.trimmingCharacters(in: .whitespaces)
    return vendor.isEmpty ? product : vendor + " " + product
  }

  static let months = [
    "January", "February", "March", "April", "May", "June", "July", "August", "September",
    "October", "November", "December",
  ]

  /// *25 October*: the day, in `zone`.
  static func day(_ instant: Date, in zone: TimeZone) -> String {
    let clock = DiveComputerArchive.clock(instant, in: zone)
    return "\(clock.date.day) \(months[clock.date.month - 1])"
  }

  private static func count(_ dives: Int) -> String {
    dives == 1 ? "1 dive" : "\(dives) dives"
  }
}
