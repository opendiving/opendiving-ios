import Testing

@testable import OpenDivingKit

struct LetterIndexTests {
  @Test func aNameFilesUnderItsFirstLetterInCapitalsWithoutItsAccent() {
    #expect(LetterIndex.letter(of: "blue Lagoon") == "B")
    #expect(LetterIndex.letter(of: "Élan Divers") == "E")
    #expect(LetterIndex.letter(of: "  ödön") == "O")
    #expect(LetterIndex.letter(of: "Дайв-центр") == "Д")
  }

  @Test func aNameWithNoLetterFirstFilesUnderOther() {
    #expect(LetterIndex.letter(of: "7 Seas") == "#")
    #expect(LetterIndex.letter(of: "@home") == "#")
    #expect(LetterIndex.letter(of: "") == "#")
    #expect(LetterIndex.letter(of: "   ") == "#")
  }

  @Test func sectionsKeepTheListsOrderAndPutOtherLast() {
    let names = ["3 Fish", "Abyss", "aqua", "Blue", "Ümit", "Uno", "Zed", "apnea"]
    let sections = LetterIndex.sections(names) { $0 }
    #expect(sections.map(\.letter) == ["A", "B", "U", "Z", "#"])
    #expect(
      sections.map(\.items) == [
        ["Abyss", "aqua", "apnea"], ["Blue"], ["Ümit", "Uno"], ["Zed"], ["3 Fish"],
      ])
  }

  @Test func noItemsMakeNoSections() {
    #expect(LetterIndex.sections([String]()) { $0 }.isEmpty)
  }

  @Test func aTouchFallsOnTheLetterItsShareOfTheIndexHolds() {
    let letters = ["A", "B", "C", "D"]
    #expect(LetterIndex.letter(at: 0, height: 80, letters: letters) == "A")
    #expect(LetterIndex.letter(at: 19.9, height: 80, letters: letters) == "A")
    #expect(LetterIndex.letter(at: 20, height: 80, letters: letters) == "B")
    #expect(LetterIndex.letter(at: 79, height: 80, letters: letters) == "D")
  }

  @Test func aTouchBeyondTheIndexTakesTheNearestLetter() {
    let letters = ["A", "B", "C"]
    #expect(LetterIndex.letter(at: -30, height: 60, letters: letters) == "A")
    #expect(LetterIndex.letter(at: 200, height: 60, letters: letters) == "C")
    #expect(LetterIndex.letter(at: 10, height: 0, letters: letters) == "A")
    #expect(LetterIndex.letter(at: 10, height: 60, letters: []) == nil)
  }
}
