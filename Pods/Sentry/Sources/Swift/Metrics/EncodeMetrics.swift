import Foundation

/// Encodes the metrics into a Statsd compatible format.
/// See https://github.com/statsd/statsd#usage and https://getsentry.github.io/relay/relay_metrics/index.html for more details about the format.
func encodeToStatsd(flushableBuckets: [BucketTimestamp: [Metric]]) -> Data {
    var statsdString = ""

    for bucket in flushableBuckets {
        let timestamp = bucket.key
        let buckets = bucket.value
        for metric in buckets {

            statsdString.append(sanitize(metricKey: metric.key))
            statsdString.append("@")

            statsdString.append(sanitize(metricUnit: metric.unit.unit))

            for serializedValue in metric.serialize() {
                statsdString.append(":\(serializedValue)")
            }

            statsdString.append("|")
            statsdString.append(metric.type.rawValue)

            var firstTag = true
            for (tagKey, tagValue) in metric.tags {
                let sanitizedTagKey = sanitize(tagKey: tagKey)

                if firstTag {
                    statsdString.append("|#")
                    firstTag = false
                } else {
                    statsdString.append(",")
                }

                statsdString.append("\(sanitizedTagKey):")
                statsdString.append(replaceTagValueCharacters(tagValue: tagValue))
            }

            statsdString.append("|T")
            statsdString.append("\(timestamp)")
            statsdString.append("\n")
        }
    }

    return statsdString.data(using: .utf8) ?? Data()
}

private func sanitize(metricUnit: String) -> String {
    // We can't use \w because it includes chars like ä on Swift
    return metricUnit.replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "", options: .regularExpression)
}

private func sanitize(metricKey: String) -> String {
    // We can't use \w because it includes chars like ä on Swift
    return metricKey.replacingOccurrences(of: "[^a-zA-Z0-9_.-]+", with: "_", options: .regularExpression)
}

private func sanitize(tagKey: String) -> String {
    // We can't use \w because it includes chars like ä on Swift
    return tagKey.replacingOccurrences(of: "[^a-zA-Z0-9_/.-]+", with: "", options: .regularExpression)
}

private func replaceTagValueCharacters(tagValue: String) -> String {
    var result = tagValue.replacingOccurrences(of: "\\", with: #"\\\\"#)
    result = result.replacingOccurrences(of: "\n", with: #"\\n"#)
    result = result.replacingOccurrences(of: "\r", with: #"\\r"#)
    result = result.replacingOccurrences(of: "\t", with: #"\\t"#)
    result = result.replacingOccurrences(of: "|", with: #"\\u{7c}"#)
    return result.replacingOccurrences(of: ",", with: #"\\u{2c}"#)

}
