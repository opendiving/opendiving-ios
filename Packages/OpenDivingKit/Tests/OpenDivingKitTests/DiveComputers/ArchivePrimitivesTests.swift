import Foundation
import Testing

@testable import OpenDivingKit

/// The digests, the JSON printer and the zip the archive writer is built from, each against
/// published vectors or a round trip.
struct ArchivePrimitivesTests {
  /// FIPS 180-4's examples, and NIST's million `a`.
  @Test func sha256MatchesThePublishedVectors() {
    #expect(
      SHA256Digest.hex(Data())
        == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    #expect(
      SHA256Digest.hex(Data("abc".utf8))
        == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    #expect(
      SHA256Digest.hex(Data("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".utf8))
        == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
    #expect(
      SHA256Digest.hex(Data(repeating: UInt8(ascii: "a"), count: 1_000_000))
        == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
  }

  @Test func sha1MatchesThePublishedVectors() {
    #expect(Hex.lowercase(SHA1Digest.digest(Data())) == "da39a3ee5e6b4b0d3255bfef95601890afd80709")
    #expect(
      Hex.lowercase(SHA1Digest.digest(Data("abc".utf8)))
        == "a9993e364706816aba3e25717850c26c9cd0d89d")
    #expect(
      Hex.lowercase(
        SHA1Digest.digest(Data("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".utf8)))
        == "84983e441c3bd26ebaae4aa1f95129e5e54670f1")
  }

  /// RFC 9562's check value, and Python's `uuid.uuid5(uuid.NAMESPACE_DNS, "python.org")`.
  @Test func crc32AndVersion5UUIDsMatchTheirVectors() {
    #expect(CRC32.checksum(Data("123456789".utf8)) == 0xCBF4_3926)
    #expect(CRC32.checksum(Data()) == 0)
    let dns = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!
    #expect(
      UUID.version5(namespace: dns, name: "python.org")
        == UUID(uuidString: "886313e1-3b8a-5372-9b90-0c9aee199e5d"))
  }

  @Test func jsonPrintsSortedCompactAndTheSameAfterAParse() throws {
    let value: ArchiveJSON = .object([
      "b": .array([.integer(1), .number(1.5), .number(21), .bool(true), .bool(false)]),
      "a": .string("quote \" slash \\ tab \t bell \u{07} é"),
      "c": .number(0.000_01),
    ])
    let text = value.text
    #expect(
      text
        == #"{"a":"quote \" slash \\ tab \t bell \u0007 é","b":[1,1.5,21,true,false],"c":1e-05}"#)
    let parsed = try #require(ArchiveJSON.parse(Data(text.utf8)))
    #expect(parsed.text == text)
    #expect(parsed["b"]?.arrayValue?[3] == .bool(true))
    #expect(parsed["b"]?.arrayValue?[0] == .integer(1))
  }

  @Test func aZipRoundTripsAndChecksItsMembers() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
      "ZipTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("a.zip")
    var zip = try ZipWriter(
      creating: url, moment: Date(timeIntervalSince1970: 1_793_000_000), zone: .gmt)
    try zip.add("logbook.divejson", Data("{}".utf8))
    try zip.add("files/a.bin", Data([0, 1, 2, 255]))
    try zip.add("files/empty.bin", Data())
    try zip.finish()

    let reader = try ZipReader(url)
    #expect(reader.entries.map(\.name) == ["logbook.divejson", "files/a.bin", "files/empty.bin"])
    #expect(try reader.read(reader.entries[1]) == Data([0, 1, 2, 255]))
    #expect(try reader.read(reader.entries[2]) == Data())
    #expect(ZipReader.isFullExport(url))

    var bytes = try Data(contentsOf: url)
    let at = try #require(bytes.firstRange(of: Data([0, 1, 2, 255]))).lowerBound
    bytes[at] = 9
    try bytes.write(to: url)
    #expect(throws: ZipError.unreadable) { try ZipReader(url).read(reader.entries[1]) }

    try Data("not a zip".utf8).write(to: url)
    #expect(!ZipReader.isFullExport(url))
  }
}
