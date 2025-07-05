import Foundation

@objcMembers
public class SentryEventDecoder: NSObject {
    @_spi(Private) public static func decodeEvent(jsonData: Data) -> Event? {
        return decodeFromJSONData(jsonData: jsonData) as SentryEventDecodable?
    }
}
