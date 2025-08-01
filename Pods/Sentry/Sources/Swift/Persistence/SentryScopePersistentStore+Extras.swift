@_implementationOnly import _SentryPrivate

extension SentryScopePersistentStore {
    func encode(extras: [String: Any]) -> Data? {
        return encode(extras, "extras", true)
    }
    
    func decodeExtras(from data: Data) -> [String: Any]? {
        return decode(from: data, "extras")
    }
}
