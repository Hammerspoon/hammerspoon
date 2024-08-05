import Foundation

/// Used for correlating metrics to spans. See https://github.com/getsentry/rfcs/blob/main/text/0123-metrics-correlation.md
///
@objc class LocalMetricsAggregator: NSObject {
    
    private struct Metric {
        let min: Double
        let max: Double
        let count: Int
        let sum: Double
        let tags: [String: String]
    }
    
    private var metricBuckets: [String: [String: Metric]] = [:]
    private let lock = NSLock()
    
    func add(type: MetricType, key: String, value: Double, unit: MeasurementUnit, tags: [String: String]) {

        let exportKey = unit.unit.isEmpty ? "\(type.rawValue):\(key)" : "\(type.rawValue):\(key)@\(unit.unit)" 
        let tagsKey = tags.getMetricsTagsKey()
        
        lock.synchronized {
            var bucket = metricBuckets[exportKey] ?? [:]
            
            var metric = bucket[tagsKey] ?? Metric(min: value, max: value, count: 1, sum: value, tags: tags)
            
            if bucket[tagsKey] != nil {
                let newMin = min(metric.min, value)
                let newMax = max(metric.max, value)
                let newSum = metric.sum + value
                let count = metric.count + 1
                
                metric = Metric(min: newMin, max: newMax, count: count, sum: newSum, tags: tags)
            }
            
            bucket[tagsKey] = metric
            metricBuckets[exportKey] = bucket
        }
    }
    
    @objc func serialize() -> [String: [[String: Any]]] {
        var returnValue: [String: [[String: Any]]] = [:]
        
        lock.synchronized {
            
            for (exportKey, bucket) in metricBuckets {
                
                var metrics: [[String: Any]] = []
                for (_, metric) in bucket {
                    var dict: [String: Any] = [
                        "min": metric.min,
                        "max": metric.max,
                        "count": metric.count,
                        "sum": metric.sum
                    ]
                    if !metric.tags.isEmpty {
                        dict["tags"] = metric.tags
                    }
                    
                    metrics.append(dict)
                }
                
                returnValue[exportKey] = metrics
            }
        }
        
        return returnValue
    }
}
