import Foundation

class DistributionMetric: Metric {

    private var values: [Double]
    var weight: UInt {
        return UInt(values.count)
    }

    init(first: Double, key: String, unit: MeasurementUnit, tags: [String: String]) {
        values = [first]
        super.init(type: .distribution, key: key, unit: unit, tags: tags)
    }

    func add(value: Double) {
        self.values.append(value)
    }

    func serialize() -> [String] {
        return values.map { "\($0)" }
    }
}
