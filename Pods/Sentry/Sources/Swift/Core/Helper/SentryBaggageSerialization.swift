import Foundation

@objcMembers
class SentryBaggageSerialization: NSObject {
    
    private static let SENTRY_BAGGAGE_MAX_SIZE = 8_192
    
    static func encodeDictionary(_ dictionary: [String: String]) -> String {
        var items: [String] = []
        items.reserveCapacity(dictionary.count)
        
        var allowedSet = CharacterSet.alphanumerics
        allowedSet.insert(charactersIn: "-_.")
        var currentSize = 0
        
        for (key, value) in dictionary {
            guard let keyDescription = key.addingPercentEncoding(withAllowedCharacters: allowedSet), 
            let valueDescription = value.addingPercentEncoding(withAllowedCharacters: allowedSet), !keyDescription.isEmpty && !valueDescription.isEmpty  else {
                continue
            }
            
            let item = "\(keyDescription)=\(valueDescription)"
            if item.count + currentSize <= SENTRY_BAGGAGE_MAX_SIZE {
                currentSize += item.count + 1 // +1 is to account for the comma that will be added for each extra item
                items.append(item)
            }
        }
        
        return items.sorted().joined(separator: ",")
    }
    
    static func decode(_ baggage: String) -> [String: String] {
        guard !baggage.isEmpty else {
            return [:]
        }
        
        var decoded: [String: String] = [:]
        
        let properties = baggage.components(separatedBy: ",")
        
        for property in properties {
            let parts = property.components(separatedBy: "=")
            guard parts.count == 2 else {
                continue
            }
            let key = parts[0]
            if let value = parts[1].removingPercentEncoding {
                decoded[key] = value
            }
        }
        
        return decoded
    }
}
