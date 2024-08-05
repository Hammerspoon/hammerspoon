import Foundation

typealias Metric = MetricBase & MetricProtocol

protocol MetricProtocol {

    var weight: UInt { get }
    func serialize() -> [String]
}

class MetricBase {

    let type: MetricType
    let key: String
    let unit: MeasurementUnit
    let tags: [String: String]

    init(type: MetricType, key: String, unit: MeasurementUnit, tags: [String: String]) {
        self.type = type
        self.key = key
        self.unit = unit
        self.tags = tags
    }
}

enum MetricType: Character {
    case counter = "c"
    case gauge = "g"
    case distribution = "d"
    case set = "s"
}
