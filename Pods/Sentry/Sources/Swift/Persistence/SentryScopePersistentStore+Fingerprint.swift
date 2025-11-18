@_implementationOnly import _SentryPrivate

extension SentryScopePersistentStore {
    func encode(fingerprint: [String]) -> Data? {
        return encode(fingerprint, "fingerprint", false)
    }

    func decodeFingerprint(from data: Data) -> [String]? {
        guard let deserialized = SentrySerialization.deserializeArray(fromJsonData: data) else {
            SentrySDKLog.error("Failed to deserialize fingerprint, reason: data is not valid json")
            return nil
        }

        if let stringArray = deserialized as? [String] {
            return stringArray
        }
        
        SentrySDKLog.warning("Non string found in fingerprint array, returning only string elements")
        return deserialized.compactMap { $0 as? String }
    }
}
