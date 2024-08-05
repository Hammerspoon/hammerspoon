import Foundation

class CounterMetric: Metric {

    private var value: Double
    var weight: UInt = 1

    init(first: Double, key: String, unit: MeasurementUnit, tags: [String: String]) {
        value = first
        super.init(type: .counter, key: key, unit: unit, tags: tags)
    }

    func add(value: Double) {
        self.value += value
    }

    func serialize() -> [String] {
        return ["\(value)"]
    }
}
