import Foundation

/// Represents arbitrary data that can be decoded from JSON with Decodable.
///
/// - Note: Some classes on the protocol allow adding extra data in a dictionary of type String:Any.
/// Users can put anything in there that can be serialized to JSON. The SDK uses JSONSerialization to
/// serialize these dictionaries. At first glance, you could assume that we can use JSONSerialization.jsonObject(with:options)
/// to deserialize these dictionaries, but we can't. When using Decodable, you don't have access to the raw
/// data of the JSON. The Decoder and the DecodingContainers don't offer methods to access the underlying
/// data. The Swift Decodable converts the raw data to a JSON object and then casts the JSON object to the
/// class that implements the Decodable protocol, see:
/// https://github.com/swiftlang/swift-foundation/blob/e9d59b6065ad909fee15f174bd5ca2c580490388/Sources/FoundationEssentials/JSON/JSONDecoder.swift#L360-L386
/// https://github.com/swiftlang/swift-foundation/blob/e9d59b6065ad909fee15f174bd5ca2c580490388/Sources/FoundationEssentials/JSON/JSONScanner.swift#L343-L383

/// Therefore, we have to implement decoding the arbitrary dictionary manually.
///
/// A discarded option is to decode the JSON raw data twice: once with Decodable and once with the JSONSerialization.
/// This has two significant downsides: First, we deserialize the JSON twice, which is a performance overhead. Second,
/// we don't conform to the Decodable protocol, which could lead to unwanted hard-to-detect problems in the future.
enum ArbitraryData: Decodable {
    case string(String)
    case int(Int)
    case number(Double)
    case boolean(Bool)
    case date(Date)
    case dict([String: ArbitraryData])
    case array([ArbitraryData])
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // The order here matters as we're dealing with arbitrary data.
        // We have to check the double before the Date, because otherwise
        // a double value could turn into a Date. So only ISO 8601 string formatted
        // dates work, which sanitizeArray and sentry_sanitize use.
        // We must check String after Date, because otherwise we would turn a ISO 8601
        // string into a string and not a date.
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let numberValue = try? container.decode(Double.self) {
            self = .number(numberValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .boolean(boolValue)
        } else if let dateValue = try? container.decode(Date.self) {
            self = .date(dateValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let objectValue = try? container.decode([String: ArbitraryData].self) {
            self = .dict(objectValue)
        } else if let arrayValue = try? container.decode([ArbitraryData].self) {
            self = .array(arrayValue)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid JSON value"
            )
        }
    }
}

func decodeArbitraryData(decode: () throws -> [String: ArbitraryData]?) -> [String: Any]? {
    do {
        let rawData = try decode()
        if rawData == nil {
            return nil
        }
        
        return unwrapArbitraryDict(rawData)
    } catch {
        SentrySDKLog.error("Failed to decode raw data: \(error)")
        return nil
    }
}

func decodeArbitraryData(decode: () throws -> [String: [String: ArbitraryData]]?) -> [String: [String: Any]]? {
    do {
        let rawData = try decode()
        if rawData == nil {
            return nil
        }
        
        var newData = [String: [String: Any]]()
        for (key, value) in rawData ?? [:] {
            newData[key] = unwrapArbitraryDict(value)
        }
        
        return newData
    } catch {
        SentrySDKLog.error("Failed to decode raw data: \(error)")
        return nil
    }
}

private func unwrapArbitraryDict(_ dict: [String: ArbitraryData]?) -> [String: Any]? {
    guard let nonNullDict = dict else {
        return nil
    }
    
    return nonNullDict.mapValues { unwrapArbitraryValue($0) as Any }
}

private func unwrapArbitraryArray(_ array: [ArbitraryData]?) -> [Any]? {
    guard let nonNullArray = array else {
        return nil
    }

    return nonNullArray.map { unwrapArbitraryValue($0) as Any }
}

private func unwrapArbitraryValue(_ value: ArbitraryData?) -> Any? {
    switch value {
    case .string(let stringValue):
        return stringValue
    case .number(let numberValue):
        return numberValue
    case .int(let intValue):
        return intValue
    case .boolean(let boolValue):
        return boolValue
    case .date(let dateValue):
        return dateValue
    case .dict(let dictValue):
        return unwrapArbitraryDict(dictValue)
    case .array(let arrayValue):
        return unwrapArbitraryArray(arrayValue)
    case .null:
        return NSNull()
    case .none:
        return nil
    }
}
