import Foundation

protocol MetricsAggregator {
    func increment(key: String, value: Double, unit: MeasurementUnit, tags: [String: String], localMetricsAggregator: LocalMetricsAggregator?)
    
    func gauge(key: String, value: Double, unit: MeasurementUnit, tags: [String: String], localMetricsAggregator: LocalMetricsAggregator?)
    
    func distribution(key: String, value: Double, unit: MeasurementUnit, tags: [String: String], localMetricsAggregator: LocalMetricsAggregator?)
    
    func set(key: String, value: UInt, unit: MeasurementUnit, tags: [String: String], localMetricsAggregator: LocalMetricsAggregator?)

    func flush(force: Bool)
    func close()
}

extension Dictionary where Key == String, Value == String {
    func getMetricsTagsKey() -> String {
        // It's important to sort the tags in order to
        // obtain the same bucket key.
        return self.sorted(by: { $0.key < $1.key }).map({ "\($0.key)=\($0.value)" }).joined(separator: ",")
    }
}

class NoOpMetricsAggregator: MetricsAggregator {
    func increment(key: String, value: Double, unit: MeasurementUnit, tags: [String: String], localMetricsAggregator: LocalMetricsAggregator?) {
        // empty on purpose
    }
    
    func gauge(key: String, value: Double, unit: MeasurementUnit, tags: [String: String], localMetricsAggregator: LocalMetricsAggregator?) {
        // empty on purpose
    }
    
    func distribution(key: String, value: Double, unit: MeasurementUnit, tags: [String: String], localMetricsAggregator: LocalMetricsAggregator?) {
        // empty on purpose
    }
    
    func set(key: String, value: UInt, unit: MeasurementUnit, tags: [String: String], localMetricsAggregator: LocalMetricsAggregator?) {
        // empty on purpose
    }

    func flush(force: Bool) {
        // empty on purpose
    }

    func close() {
        // empty on purpose
    }
}
