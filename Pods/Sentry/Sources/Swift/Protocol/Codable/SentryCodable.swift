@_implementationOnly import _SentryPrivate
import Foundation

func encodeToJSONData<T: Encodable>(data: T) throws -> Data {
    let jsonEncoder = JSONEncoder()
    jsonEncoder.dateEncodingStrategy = .secondsSince1970
    return try jsonEncoder.encode(data)
}

func decodeFromJSONData<T: Decodable>(jsonData: Data) -> T? {
    if jsonData.isEmpty {
        return nil
    }
    
    do {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            
            // We prefer a Double/TimeInterval because it allows nano second precision.
            // The ISO8601 formatter only supports millisecond precision.
            if let timeIntervalSince1970 = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timeIntervalSince1970)
            }
            
            if let dateString = try? container.decode(String.self) {
                let formatter = sentryGetIso8601FormatterWithMillisecondPrecision()
                guard let date = formatter.date(from: dateString) else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format. The following string doesn't represent a valid ISO 8601 date string: '\(dateString)'")
                }
                
                return date
            }
            
            throw DecodingError.typeMismatch(Date.self, DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Invalid date format. The Date must either be a Double/TimeInterval representing the timeIntervalSince1970 or it can be a ISO 8601 formatted String."
            ))

        }
        return try decoder.decode(T.self, from: jsonData)
    } catch {
        SentrySDKLog.error("Could not decode object of type \(T.self) from JSON data due to error: \(error)")
    }
    
    return nil
}
