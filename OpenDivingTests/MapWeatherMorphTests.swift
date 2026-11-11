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
}
