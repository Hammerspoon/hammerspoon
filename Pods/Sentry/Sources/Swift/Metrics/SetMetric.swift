import Foundation

class SetMetric: Metric {

    private var set: Set<UInt>
    var weight: UInt {
        return UInt(set.count)
    }

    init(first: UInt, key: String, unit: MeasurementUnit, tags: [String: String]) {
        set = [first]
        super.init(type: .set, key: key, unit: unit, tags: tags)
    }

    func add(value: UInt) {
        set.insert(value)
    }

    func serialize() -> [String] {
        return set.map { "\($0)" }
    }
}
