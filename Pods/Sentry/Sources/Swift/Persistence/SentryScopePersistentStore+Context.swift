@_implementationOnly import _SentryPrivate

extension SentryScopePersistentStore {
    func encode(context: [String: [String: Any]]) -> Data? {
        return encode(context, "context", true)
    }
    
    func decodeContext(from data: Data) -> [String: [String: Any]]? {
        return decode(from: data, "context")
    }
}
