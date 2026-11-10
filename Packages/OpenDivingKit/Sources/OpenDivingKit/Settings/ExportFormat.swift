/// The four shapes `GET /export/…` serves the account's logbook in, in the order *Data* lists
/// them, each with the web's words for what is in it.
public enum ExportFormat: String, CaseIterable, Hashable, Sendable, Identifiable {
  case divejson
  case uddf
  case csv
  case archive

  public var id: String { rawValue }

  /// The route under the API base.
  var path: String { "export/\(rawValue)" }

  /// What a file of this format is called when the server names none.
  var fallbackFilename: String {
    "opendiving-export." + (self == .archive ? "zip" : rawValue)
  }

  public var title: String {
    switch self {
    case .divejson: "DiveJSON"
    case .uddf: "UDDF"
    case .csv: "Spreadsheet"
    case .archive: "Full archive"
    }
  }

  /// What the file holds, rather than what the format is.
  public var summary: String {
    switch self {
    case .divejson:
      "Your whole logbook in one file: every dive with every recording that made it — each"
        + " one's device, its files and its full sample profile — plus cylinders, sites, trips,"
        + " courses, marine life, gear with its service history, your c-card records, your"
        + " contacts, the people you dive with and your tags. Everything in the account except"
        + " your dive drafts and the uploaded files themselves, which it names by digest."
        + " DiveJSON is the open dive-log format this project maintains, and this app is its"
        + " reference implementation — so this is the one that comes back with nothing lost."
    case .uddf:
      "Every dive with its sites, trips, gases, cylinders, gear and sample profile, plus your"
        + " contacts — as dive bases, shops and the places you stayed — the people you dive"
        + " with, as buddies, and your date of birth, phone, check-in email and insurance"
        + " policies, in the open format Subsurface, MacDive and divelogs.de import. A dive"
        + " recorded by two computers writes one profile here — the recording shown by default"
        + " — because a UDDF dive carries one set of samples; the DiveJSON and the archive carry"
        + " them all. This is the file to hand another program, and the Import page reads it"
        + " back too — gear sets, service history, your courses, your c-cards, who came on a"
        + " trip, the roles on a dive beyond buddy and guide, a dive's tags, waves, weather and"
        + " boat name, a dive site's tags, water type, entry types and OpenStreetMap or Wikidata"
        + " entries, a contact's place on the map, your emergency contacts and your policy"
        + " numbers have no slot in it, and ride in the DiveJSON and the archive instead."
    case .csv:
      "One row per dive, flattened for Excel, Numbers or a notebook. The normalized set —"
        + " cylinders, trips, sites, gear, service history, courses, certifications, contacts,"
        + " people, tags — rides in the DiveJSON, and as its own CSVs inside the archive."
    case .archive:
      "Everything, as a zip: the DiveJSON, the UDDF, the full CSV set, every dive-computer file"
        + " you uploaded — each under the recording it belongs to — every certification card"
        + " image you uploaded, and your dive drafts, which an import leaves out. This is the one"
        + " to keep as a backup — it is also the only download that can put those files back,"
        + " since an import can restore only the bytes it actually carries. Your portrait is in"
        + " it too, and importing the archive offers it back beside yours. The card scans and"
        + " the portrait are personal documents, so treat the file as one."
    }
  }
}
