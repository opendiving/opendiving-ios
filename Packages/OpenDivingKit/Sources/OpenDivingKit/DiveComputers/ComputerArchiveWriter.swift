import Foundation

/// Turns a download into one DiveJSON archive on disk — `logbook.divejson` at the root and each
/// dive's original bytes under `files/`, the spec's archive convention and the api's — and
/// unites download archives that wait unimported into one.
///
/// A dive is named `{make-model}_{serial}_{YYYY-MM-DDThhmm}.bin` after its start, or after its
/// fingerprint's hex where nothing gave it one; the archive after the download's moment, with a
/// `.zip` suffix, or `dive-computers_{YYYY-MM-DDThhmm}.zip` where it holds more than one
/// computer's dives. The name is what carries the computer to the server beside the device
/// block, since the api keeps a stored file's name and none of its extensions.
public struct ComputerArchiveWriter: Sendable {
  /// What the document's `generator` names.
  public struct Generator: Hashable, Sendable {
    public let name: String
    public let version: String

    public init(name: String, version: String) {
      self.name = name
      self.version = version
    }
  }

  /// One download, ready to write.
  public struct Download: Hashable, Sendable {
    public let identity: DiveComputerIdentity
    /// Newest first, as the computer walks them; a refused reading's bytes travel unnamed.
    public let dives: [DownloadedDive]
    /// When it was downloaded, and the phone's zone, which the names and `exported_at` use.
    public let moment: Date
    public let zone: TimeZone
    /// The zone an instant start is written in: the diver's for this computer where set, else
    /// the watch's. Needed only where a dive's start is an instant.
    public let instantZone: TimeZone?

    public init(
      identity: DiveComputerIdentity, dives: [DownloadedDive], moment: Date, zone: TimeZone,
      instantZone: TimeZone?
    ) {
      self.identity = identity
      self.dives = dives
      self.moment = moment
      self.zone = zone
      self.instantZone = instantZone
    }
  }

  /// An archive written, and what the inbox records of it.
  public struct Written: Hashable, Sendable {
    public let url: URL
    public let download: InboxDownload
  }

  public let generator: Generator

  public init(generator: Generator) {
    self.generator = generator
  }

  /// Writes `download` as one archive into `directory`.
  public func write(_ download: Download, into directory: URL) throws -> Written {
    let identity = download.identity
    let slug = DiveComputerArchive.slug(vendor: identity.vendor, product: identity.product)
    let serial = DiveComputerArchive.fileSerial(identity.serial)
    var dives: [ArchiveJSON] = []
    var members: [Member] = []
    var used: Set<String> = []
    for downloaded in download.dives {
      let resolved: (text: String, clock: LocalDateTime)?
      switch downloaded.reading {
      case .dive(let dive):
        resolved = try DiveComputerArchive.start(dive.start, zone: download.instantZone)
      case .refused(let start):
        resolved = start.flatMap {
          try? DiveComputerArchive.start($0, zone: download.instantZone)
        }
      }
      let stamp =
        resolved.map { DiveComputerArchive.minute($0.clock) }
        ?? Hex.lowercase(downloaded.fingerprint)
      let filename = Self.unique("\(slug)_\(serial)_\(stamp).bin", in: &used)
      let path = DiveComputerArchive.filesFolder + filename
      members.append(Member(path: path, source: .bytes(downloaded.bytes)))
      guard case .dive(let dive) = downloaded.reading, let resolved else { continue }
      let storedFile: ArchiveJSON = .object([
        "uuid": .string(
          DiveComputerArchive.fileUUID(downloaded.identity, fingerprint: downloaded.fingerprint)
            .uuidString.lowercased()),
        "original_filename": .string(filename),
        "content_type": .string("application/octet-stream"),
        "byte_size": .integer(downloaded.bytes.count),
        "sha256": .string(SHA256Digest.hex(downloaded.bytes)),
        "archive_path": .string(path),
      ])
      dives.append(
        ComputerDiveDocument.dive(
          dive, identity: downloaded.identity,
          uuid: DiveComputerArchive.diveUUID(
            downloaded.identity, fingerprint: downloaded.fingerprint),
          startedAt: resolved.text, storedFile: storedFile))
    }
    let clock = DiveComputerArchive.clock(download.moment, in: download.zone)
    let url = directory.appendingPathComponent(
      "\(slug)_\(serial)_\(DiveComputerArchive.minute(clock)).zip", isDirectory: false)
    try write(dives: dives, members: members, moment: download.moment, zone: download.zone, to: url)
    let computer = InboxDownload.Computer(
      family: identity.family, vendor: identity.vendor, product: identity.product,
      serial: identity.serial, dives: dives.count)
    return Written(
      url: url, download: InboxDownload(computers: [computer], downloadedAt: download.moment))
  }

  /// Writes into `directory` the union of `archives` — download archives this writer wrote,
  /// each with the inbox's record of it, the newest first. Each dive is kept once, by its
  /// derived uuid, as the first archive holding it has it, with the members its document names;
  /// a member no document names — a refused dive's bytes — is kept once by digest.
  public func unite(
    _ archives: [(url: URL, download: InboxDownload)], moment: Date, zone: TimeZone,
    into directory: URL
  ) throws -> Written {
    var dives: [ArchiveJSON] = []
    var members: [Member] = []
    var seenDives: Set<String> = []
    var paths: [String: String] = [:]
    var unnamedDigests: Set<String> = []
    var computers: [InboxDownload.Computer] = []
    for archive in archives {
      for computer in archive.download.computers
      where !computers.contains(where: { Self.same($0, computer) }) {
        var fresh = computer
        fresh.dives = 0
        computers.append(fresh)
      }
      let reader: ZipReader
      let document: ArchiveJSON
      do {
        reader = try ZipReader(archive.url)
        guard
          let entry = reader.entries.first(where: { $0.name == DiveComputerArchive.documentName }),
          let parsed = ArchiveJSON.parse(try reader.read(entry))
        else { throw DiveComputerArchiveError.unreadableArchive }
        document = parsed
      } catch {
        throw DiveComputerArchiveError.unreadableArchive
      }
      let entries = Dictionary(
        reader.entries.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
      var named: Set<String> = [DiveComputerArchive.documentName]
      for dive in document["dives"]?.arrayValue ?? [] {
        let files = Self.storedFiles(dive)
        named.formUnion(files.compactMap { $0["archive_path"]?.stringValue })
        guard let uuid = dive["uuid"]?.stringValue, seenDives.insert(uuid).inserted else {
          continue
        }
        var dive = dive
        for file in files {
          guard let path = file["archive_path"]?.stringValue, let entry = entries[path],
            let digest = file["sha256"]?.stringValue
          else { continue }
          if paths[path] == digest { continue }
          var taken = Set(paths.keys)
          let target =
            paths[path] == nil
            ? path
            : DiveComputerArchive.filesFolder
              + Self.unique(Self.base(path), in: &taken, prefix: DiveComputerArchive.filesFolder)
          if target != path { dive = Self.renaming(dive, path, to: target) }
          paths[target] = digest
          members.append(Member(path: target, source: .entry(reader, entry)))
        }
        dives.append(dive)
        if let serial = dive["recordings"]?.arrayValue?.first?["device"]?["serial"]?.stringValue,
          let index = computers.firstIndex(where: {
            $0.serial.uppercased() == serial.uppercased()
          })
        {
          computers[index].dives += 1
        }
      }
      for entry in reader.entries where !named.contains(entry.name) {
        let bytes = try reader.read(entry)
        guard unnamedDigests.insert(SHA256Digest.hex(bytes)).inserted else { continue }
        var taken = Set(paths.keys)
        let path =
          DiveComputerArchive.filesFolder
          + Self.unique(Self.base(entry.name), in: &taken, prefix: DiveComputerArchive.filesFolder)
        paths[path] = ""
        members.append(Member(path: path, source: .bytes(bytes)))
      }
    }
    let clock = DiveComputerArchive.clock(moment, in: zone)
    let name: String
    if computers.count == 1, let only = computers.first {
      name =
        "\(DiveComputerArchive.slug(vendor: only.vendor, product: only.product))_"
        + "\(DiveComputerArchive.fileSerial(only.serial))_\(DiveComputerArchive.minute(clock)).zip"
    } else {
      name = "dive-computers_\(DiveComputerArchive.minute(clock)).zip"
    }
    let url = directory.appendingPathComponent(name, isDirectory: false)
    try write(dives: dives, members: members, moment: moment, zone: zone, to: url)
    return Written(url: url, download: InboxDownload(computers: computers, downloadedAt: moment))
  }

  // MARK: - Internals

  private struct Member {
    enum Source {
      case bytes(Data)
      case entry(ZipReader, ZipReader.Entry)
    }

    let path: String
    let source: Source
  }

  private func write(
    dives: [ArchiveJSON], members: [Member], moment: Date, zone: TimeZone, to url: URL
  ) throws {
    let document: ArchiveJSON = .object([
      "format": .string("divejson"),
      "version": .string("1.0"),
      "exported_at": .string(DiveComputerArchive.dateTime(moment, in: zone)),
      "generator": .object(["name": .string(generator.name), "version": .string(generator.version)]
      ),
      "dives": .array(dives),
    ])
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? FileManager.default.removeItem(at: url)
    do {
      var zip = try ZipWriter(creating: url, moment: moment, zone: zone)
      try zip.add(DiveComputerArchive.documentName, Data(document.text.utf8))
      for member in members {
        switch member.source {
        case .bytes(let bytes): try zip.add(member.path, bytes)
        case .entry(let reader, let entry): try zip.add(member.path, try reader.read(entry))
        }
      }
      try zip.finish()
    } catch {
      try? FileManager.default.removeItem(at: url)
      throw error
    }
  }

  private static func storedFiles(_ dive: ArchiveJSON) -> [ArchiveJSON] {
    (dive["recordings"]?.arrayValue ?? []).flatMap { $0["source_files"]?.arrayValue ?? [] }
  }

  /// The member's name inside `files/`.
  private static func base(_ path: String) -> String {
    path.hasPrefix(DiveComputerArchive.filesFolder)
      ? String(path.dropFirst(DiveComputerArchive.filesFolder.count))
      : path.replacingOccurrences(of: "/", with: "-")
  }

  /// `dive` with the stored file at `path` moved to `target`, its `original_filename` kept.
  private static func renaming(_ dive: ArchiveJSON, _ path: String, to target: String)
    -> ArchiveJSON
  {
    guard case .object(var out) = dive, let recordings = out["recordings"]?.arrayValue else {
      return dive
    }
    out["recordings"] = .array(
      recordings.map { recording in
        guard case .object(var fields) = recording, let files = fields["source_files"]?.arrayValue
        else { return recording }
        fields["source_files"] = .array(
          files.map { file in
            guard case .object(var stored) = file, stored["archive_path"]?.stringValue == path
            else { return file }
            stored["archive_path"] = .string(target)
            return .object(stored)
          })
        return .object(fields)
      })
    return .object(out)
  }

  private static func same(_ a: InboxDownload.Computer, _ b: InboxDownload.Computer) -> Bool {
    a.family == b.family && a.serial.uppercased() == b.serial.uppercased()
  }

  /// `name`, or `name` with `-2`, `-3`… before its extension where `used` holds it.
  private static func unique(_ name: String, in used: inout Set<String>, prefix: String = "")
    -> String
  {
    var candidate = name
    var counter = 2
    while used.contains(prefix + candidate) {
      let dot = name.lastIndex(of: ".") ?? name.endIndex
      candidate = String(name[..<dot]) + "-\(counter)" + String(name[dot...])
      counter += 1
    }
    used.insert(prefix + candidate)
    return candidate
  }
}
