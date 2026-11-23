import Foundation
import Testing

@testable import OpenDivingKit

/// More's *People* files each person under their name's first letter, as Contacts does.
struct PeopleLetterSectionTests {
  private func people(_ names: [String]) throws -> [PersonRead] {
    let rows = names.enumerated().map { index, name in
      #"{"uuid":"01a0e2ed-1be1-7142-996d-\#(String(format: "%012d", index))","#
        + #""name":"\#(name)","notes":"","dive_count":0,"created_at":"2026-09-27T12:53:05Z"}"#
    }
    return try APICoding.decoder().decode(
      [PersonRead].self, from: Data("[\(rows.joined(separator: ","))]".utf8))
  }

  @Test func aNameIsFiledUnderItsFirstLetterFolded() {
    #expect(PeopleLetterSection.letter(of: "Ana Diaz") == "A")
    #expect(PeopleLetterSection.letter(of: "ben") == "B")
    #expect(PeopleLetterSection.letter(of: "  Émile") == "E")
    #expect(PeopleLetterSection.letter(of: "Юлия") == "Ю")
  }

  @Test func aNameWithNoLetterFirstIsFiledUnderTheHash() {
    #expect(PeopleLetterSection.letter(of: "4th mate") == "#")
    #expect(PeopleLetterSection.letter(of: "") == "#")
    #expect(PeopleLetterSection.letter(of: "🐢 Turtle") == "#")
  }

  @Test func theSectionsRunAlphabeticallyWithTheHashLast() throws {
    let sections = PeopleLetterSection.sections(
      try people(["9 Lives", "Ana", "ben", "Álvaro", "Chloe", "Bea"]))
    #expect(sections.map(\.letter) == ["A", "B", "C", "#"])
    #expect(sections[0].people.map(\.name) == ["Ana", "Álvaro"])
    #expect(sections[1].people.map(\.name) == ["ben", "Bea"])
    #expect(sections[3].people.map(\.name) == ["9 Lives"])
  }

  @Test func noPeopleIsNoSections() {
    #expect(PeopleLetterSection.sections([]).isEmpty)
  }
}
