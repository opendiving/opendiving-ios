import Testing

@testable import OpenDiving

@MainActor
struct MapWeatherMorphTests {
  @Test func anOpenCardWhoseWeatherIsGoneEndsAtOnce() {
    let morph = MapWeatherMorph()
    morph.open()
    morph.coversBar = true
    #expect(morph.isPresented)

    morph.dismiss()

    #expect(!morph.isPresented)
    #expect(!morph.coversBar)
    #expect(morph.progress == 0)
  }

  @Test func aPullWhoseWeatherIsGoneDoesNotOpenOnceTheCardIsLaidOut() {
    let morph = MapWeatherMorph()
    morph.pull(60)
    morph.pullEnded(predicted: 400)

    morph.dismiss()
    morph.coversBar = true

    #expect(!morph.isPresented)
    #expect(morph.progress == 0)
  }

  @Test func theCardTapsAsItStartsToGrowAndAsTheBarLandsBack() {
    let morph = MapWeatherMorph()
    morph.open()
    #expect(morph.switches == 0)

    morph.coversBar = true
    #expect(morph.switches == 1)

    // With no view to animate, the close's completion runs at once.
    morph.close()
    #expect(!morph.isPresented)
    #expect(morph.switches == 2)
  }

  @Test func aPullLetGoShortOfTheCardDoesNotTap() {
    let morph = MapWeatherMorph()
    morph.pull(60)
    morph.pullEnded(predicted: 0)
    morph.coversBar = true

    #expect(morph.switches == 0)
  }

  @Test func aPushLetGoShortOfTheBarDoesNotTapAgain() {
    let morph = MapWeatherMorph()
    morph.open()
    morph.coversBar = true

    morph.push(-30)
    morph.pushEnded(predicted: 0)

    #expect(morph.switches == 1)
  }

  @Test func aCardOpenedAgainAfterItsWeatherWentTapsAgain() {
    let morph = MapWeatherMorph()
    morph.open()
    morph.coversBar = true
    morph.dismiss()

    morph.open()
    morph.coversBar = true

    #expect(morph.switches == 2)
  }
}
