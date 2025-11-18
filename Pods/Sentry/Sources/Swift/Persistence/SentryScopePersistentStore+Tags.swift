@_implementationOnly import _SentryPrivate

extension SentryScopePersistentStore {
    func encode(tags: [String: String]) -> Data? {
        return encode(tags, "tags", false)
    }
    
    func decodeTags(from data: Data) -> [String: String]? {
        return decode(from: data, "tags")
    }
}
