// MARK: - Strings
extension SentryScopePersistentStore {
    func encode(string: String) -> Data? {
        return string.data(using: .utf8)
    }
    
    func decodeString(from data: Data) -> String? {
        return String(data: data, encoding: .utf8)
    }
}
