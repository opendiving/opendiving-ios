extension DiveProfileMath {
  /// The index of the sample nearest the instant `at`, clamped at both ends; a tie goes to
  /// the earlier sample. Nil for an empty series. Always a real sample, never an
  /// interpolated one.
  public static func nearestSampleIndex(_ times: [Int], at: Double) -> Int? {
    guard let first = times.first, let last = times.last else { return nil }
    if at <= Double(first) { return 0 }
    if at >= Double(last) { return times.count - 1 }

    var low = 0
    var high = times.count - 1
    while high - low > 1 {
      let middle = (low + high) / 2
      if Double(times[middle]) <= at {
        low = middle
      } else {
        high = middle
      }
    }
    return at - Double(times[low]) <= Double(times[high]) - at ? low : high
  }

  /// The nearest sample that is within `tolerance` of `at` **and** on the chart, or nil.
  /// Walks outward from the nearest sample rather than rejecting it when it was not drawn,
  /// so an undrawn sample cannot hide a drawn one just behind it; stops once both
  /// frontiers are out of reach.
  public static func drawnSampleIndex(
    _ times: [Int], at: Double, tolerance: Double, drawn: Set<Int>
  ) -> Int? {
    guard let nearest = nearestSampleIndex(times, at: at) else { return nil }
    var low = nearest
    var high = nearest + 1

    while low >= 0 || high < times.count {
      let lowDelta = low >= 0 ? abs(Double(times[low]) - at) : .infinity
      let highDelta = high < times.count ? abs(Double(times[high]) - at) : .infinity
      if min(lowDelta, highDelta) > tolerance { return nil }

      if lowDelta <= highDelta {
        if drawn.contains(low) { return low }
        low -= 1
      } else {
        if drawn.contains(high) { return high }
        high += 1
      }
    }
    return nil
  }
}
