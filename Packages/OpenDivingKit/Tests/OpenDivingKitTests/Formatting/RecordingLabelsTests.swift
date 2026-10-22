import OpenDivingKit
import Testing

/// Transcribed from `src/lib/dive-recordings.test.ts` at `opendiving-web` `ec014ff9`.
struct RecordingLabelsTests {
  /// `:49-100`.
  @Test func device() {
    #expect(
      RecordingLabels.device(
        brand: "Shearwater Research, Inc", model: "Perdix 3", serial: "D9772626", name: "Perdix 3")
        == "Shearwater Research, Inc Perdix 3 · D9772626")
    #expect(
      RecordingLabels.device(brand: "Suunto", model: nil, serial: "253810000400", name: "Porvoo")
        == "Suunto · 253810000400 (Porvoo)")
    #expect(
      RecordingLabels.device(brand: "suunto", model: "Suunto Ocean", serial: nil, name: nil)
        == "Suunto Ocean")
    #expect(RecordingLabels.device(brand: nil, model: nil, serial: nil, name: nil) == nil)
    #expect(
      RecordingLabels.device(brand: "  ", model: nil, serial: "D9772626", name: nil) == "D9772626")
  }

  private func settings(
    mode: String? = nil, name: String? = nil, algorithm: String? = nil, gfLow: Int? = nil,
    gfHigh: Int? = nil, conservatism: Int? = nil, salinity: String? = nil
  ) -> String? {
    RecordingLabels.settings(
      mode: mode, decoName: name, decoAlgorithm: algorithm, gfLow: gfLow, gfHigh: gfHigh,
      conservatism: conservatism, salinity: salinity)
  }

  /// `:519-658`.
  @Test func settingsLine() {
    #expect(
      settings(mode: "open_circuit", algorithm: "buhlmann", gfLow: 30, gfHigh: 85)
        == "Open circuit · Bühlmann GF 30/85")
    #expect(
      settings(mode: "open_circuit", name: "Suunto Fused RGBM 2", algorithm: "rgbm")
        == "Open circuit · Suunto Fused RGBM 2")
    #expect(settings(mode: "freedive") == "Freedive")
    #expect(settings(name: "ZHL-16C", gfLow: 40, gfHigh: 85) == "ZHL-16C GF 40/85")
    #expect(settings() == nil)
    #expect(settings(mode: "semi_closed_rebreather") == nil)
    #expect(settings(mode: "semi_closed_rebreather", name: "VPM-B") == "VPM-B")
    #expect(
      settings(mode: "gauge", name: "Suunto Fused RGBM 2", conservatism: 0)
        == "Gauge · Suunto Fused RGBM 2 · conservatism 0")
    #expect(settings(name: "Fused RGBM", conservatism: 1) == "Fused RGBM · conservatism +1")
    #expect(settings(name: "Fused RGBM", conservatism: -2) == "Fused RGBM · conservatism -2")
    #expect(
      settings(mode: "closed_circuit", algorithm: "buhlmann", gfLow: 30)
        == "Closed circuit · Bühlmann")
    #expect(
      settings(
        mode: "open_circuit", algorithm: "buhlmann", gfLow: 30, gfHigh: 85, salinity: "en13319")
        == "Open circuit · Bühlmann GF 30/85 · salinity EN13319")
    #expect(settings(salinity: "fresh") == "salinity Fresh")
    #expect(settings(salinity: "salt") == "salinity Salt")
    #expect(settings(salinity: "custom") == nil)
    #expect(settings(algorithm: "vpm") == nil)
  }

  /// `:660-700`.
  @Test func readoutsLine() {
    #expect(
      RecordingLabels.readouts(
        cnsStart: 0, cnsEnd: 9, otuStart: 0, otuEnd: 22, surfacePressureBar: 1.012)
        == "CNS 0% → 9% · OTU 0 → 22 · Surface pressure 1.012 bar")
    #expect(
      RecordingLabels.readouts(
        cnsStart: nil, cnsEnd: nil, otuStart: nil, otuEnd: 23, surfacePressureBar: nil)
        == "OTU — → 23")
    #expect(
      RecordingLabels.readouts(
        cnsStart: nil, cnsEnd: nil, otuStart: nil, otuEnd: nil, surfacePressureBar: 1.009)
        == "Surface pressure 1.009 bar")
    #expect(
      RecordingLabels.readouts(
        cnsStart: 0, cnsEnd: nil, otuStart: nil, otuEnd: nil, surfacePressureBar: nil)
        == "CNS 0% → —")
    #expect(
      RecordingLabels.readouts(
        cnsStart: nil, cnsEnd: nil, otuStart: nil, otuEnd: nil, surfacePressureBar: nil)
        == nil)
  }
}
