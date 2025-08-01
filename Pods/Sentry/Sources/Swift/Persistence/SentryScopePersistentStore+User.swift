@_implementationOnly import _SentryPrivate

extension SentryScopePersistentStore {
    func encode(user: User) -> Data? {
        guard let data = SentrySerialization.data(withJSONObject: user.serialize()) else {
            SentrySDKLog.error("Failed to serialize user, reason: user is not valid json: \(user)")
            return nil
        }
        return data
    }
    
    func decodeUser(from data: Data) -> User? {
        return decoderUserHelper(data)
    }
    
    // Swift compiler can't infer T, even if I try to cast it
    private func decoderUserHelper(_ data: Data) -> UserDecodable? {
        return decodeFromJSONData(jsonData: data)
    }
}
