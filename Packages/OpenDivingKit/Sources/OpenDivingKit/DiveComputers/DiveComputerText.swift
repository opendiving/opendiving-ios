import Foundation

/// The words of the *Dive computer* screen, the Settings list and the inbox's download rows.
public enum DiveComputerText {
  public static let connectMenuItem = "Connect a dive computer"
  public static let screenTitle = "Dive computer"
  public static let scanningHeading = "Looking for dive computers"
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
  public static let suuntoAppConnected =
    "The Suunto app is still connected to this computer. Unpair it there, then connect again."
  public static let timeZoneQuestion = "Which time zone were these dives in?"
  public static let connecting = "Connecting"

  // MARK: - Settings

  public static let settingsRow = "Dive computers"
  public static let forget = "Forget this dive computer"
  public static let forgetMessage = "The next download from it takes every dive again."
  public static let downloadAllNextTime = "Download all dives next time"
  public static let emptyList = "No dive computers yet. Connect one with + on the Dives tab."

  /// *Forget Perdix 3?*
  public static func forgetTitle(_ record: DiveComputerRecord) -> String {
    "Forget \(record.product)?"
  }

  // MARK: - The inbox

  /// Asked before *Remove* or *Remove all* takes a download archive out of the inbox.
  public static let removeDownloadWarning =
    "These dives have not been imported. The next download takes them again only with Download"
    + " all dives next time."

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

  /// *No new dives since 12 October.*
  public static func nothingNew(since: Date, in zone: TimeZone = .current) -> String {
    "No new dives since \(day(since, in: zone))."
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
