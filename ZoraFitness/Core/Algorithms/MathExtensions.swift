import Foundation

extension Collection where Element == Double {
    var mean: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }

    var standardDeviation: Double {
        guard count > 1 else { return 0 }
        let m = mean
        let variance = reduce(0) { $0 + pow($1 - m, 2) } / Double(count)
        return sqrt(variance)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// Logistic sigmoid — maps any real number to (0, 1).
// steepness controls how sharply it transitions; 1.0 = standard sigmoid.
func sigmoid(_ x: Double, steepness: Double = 1.0) -> Double {
    1.0 / (1.0 + exp(-steepness * x))
}
