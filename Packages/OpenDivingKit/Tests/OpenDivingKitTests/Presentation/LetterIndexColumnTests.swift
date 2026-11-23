import Testing

@testable import OpenDivingKit

struct LetterIndexColumnTests {
  @Test func theColumnDrawsEveryLetterAndOtherWhateverTheListHolds() {
    let column = LetterIndexColumn(filed: ["B"])
    #expect(column.letters == LetterIndexColumn.alphabet + ["#"])
    #expect(LetterIndexColumn(filed: []).letters.count == 27)
  }

  @Test func aLetterBeyondTheAlphabetJoinsAfterZ() {
    let column = LetterIndexColumn(filed: ["Ю", "A", "#", "Д"])
    #expect(column.letters.suffix(3) == ["Д", "Ю", "#"])
  }

  @Test func onlyTheFiledLettersHaveItems() {
    let column = LetterIndexColumn(filed: ["A", "M", "#"])
    #expect(column.hasItems("M"))
    #expect(!column.hasItems("B"))
    #expect(column.filedLetters == ["A", "M", "#"])
  }

  @Test func aPickLandsOnItsOwnLetterElseTheNextDownElseTheLastAbove() {
    let column = LetterIndexColumn(filed: ["C", "M"])
    #expect(column.target(of: "C") == "C")
    #expect(column.target(of: "A") == "C")
    #expect(column.target(of: "D") == "M")
    #expect(column.target(of: "#") == "M")
    #expect(column.target(of: "?") == nil)
    #expect(LetterIndexColumn(filed: []).target(of: "A") == nil)
  }
}
