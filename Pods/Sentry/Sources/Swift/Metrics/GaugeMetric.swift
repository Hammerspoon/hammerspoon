import Foundation

class GaugeMetric: Metric {

    private var last: Double
    private var min: Double
    private var max: Double
    private var sum: Double
    private var count: UInt
    
    var weight: UInt = 5

    init(first: Double, key: String, unit: MeasurementUnit, tags: [String: String]) {
        self.last = first
        self.min = first
        self.max = first
        self.sum = first
        self.count = 1
        
        super.init(type: .gauge, key: key, unit: unit, tags: tags)
    }

    func add(value: Double) {
      self.last = value
      min = Swift.min(min, value)
      max = Swift.max(max, value)
      sum += value
      count += 1
    }

    func serialize() -> [String] {
        return ["\(last)", "\(min)", "\(max)", "\(sum)", "\(count)"]
    }
}
