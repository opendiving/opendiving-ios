import Foundation

/// The words of the *Dive Computers* screen, a computer's page and the inbox's download rows.
public enum DiveComputerText {
  public static let connect = "Connect a dive computer"
  public static let screenTitle = "Dive Computers"
  public static let pairedHeading = "Paired Computers"
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
  public static let archiveWaiting =
    "Import or remove the archive waiting in the import screen first."
  public static let lockHint = "You can lock the phone. The download keeps going."
  public static let downloadAll = "Download all dives"
  public static let noDives = "No dives on this computer."
  public static let timeZoneQuestion = "Which time zone were these dives in?"
  public static let connecting = "Connecting"
  /// Once the computer is identified, until the download starts.
  public static let reading = "Reading"

  // MARK: - Forgetting

  public static let forget = "Forget this dive computer"
  public static let forgetMessage = "The next download from it takes every dive again."

  /// *Forget Perdix 3?*
  public static func forgetTitle(_ record: DiveComputerRecord) -> String {
    "Forget \(record.product)?"
  }

  // MARK: - A computer's page

  public static let serialLabel = "Serial number"
  public static let hardwareLabel = "Hardware version"
  public static let firmwareLabel = "Firmware version"
  public static let lastDownloadedLabel = "Last downloaded"

  /// *About Shearwater Perdix 3*: what the button that opens it says to VoiceOver.
  public static func about(_ title: String) -> String { "About \(title)" }

  // MARK: - The inbox

  /// Asked before *Remove* or *Remove all* takes a download archive out of the inbox.
  public static let removeDownloadWarning =
    "These dives have not been imported. The next download takes them again only with Download"
    + " all dives."

  /// *12 dives from Shearwater Perdix 3, downloaded 25 October*.
  public static func inboxRow(_ download: InboxDownload, in zone: TimeZone = .current) -> String {
    let names = download.computers.map(\.title)
    let from = names.count <= 1 ? (names.first ?? "") : PendingText.list(names)
    return
      "\(count(download.dives)) from \(from), downloaded \(day(download.downloadedAt, in: zone))"
  }

  // MARK: - Downloading

  /// *Downloading dive 3*.
  public static func downloading(_ dive: Int) -> String { "Downloading dive \(dive)" }

  /// *Downloading 2 of 3 new dives*.
  public static func downloading(_ dive: Int, of total: Int) -> String {
    "Downloading \(dive) of \(total) new " + (total == 1 ? "dive" : "dives")
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

  /// *The new dives are already waiting in the import screen.*: every new dive was downloaded
  /// before and waits there unimported.
  public static func alreadyWaiting(_ dives: Int) -> String {
    dives == 1
      ? "The new dive is already waiting in the import screen."
      : "The new dives are already waiting in the import screen."
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
  public static let unreachable =
    "The dive computer did not answer. Wake it and turn on its Bluetooth, then connect again."

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
