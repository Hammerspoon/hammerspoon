@_implementationOnly import _SentryPrivate

extension SentryScopePersistentStore {
    func encode<T>(_ genericModel: T, _ name: String, _ sanitize: Bool = false) -> Data? {
        var model: Any = genericModel
        if sanitize {
            // We need to check if the context is a valid JSON object before encoding it.
            // Otherwise it will throw an unhandled `NSInvalidArgumentException` exception.
            // The error handler is required but will never be executed due to Swift type safety.
            guard let wrapped = genericModel as? [AnyHashable: Any],
                  let sanitizedModel = sentry_sanitize(wrapped) else {
                SentrySDKLog.error("Failed to sanitize \(name), reason: \(name) is not valid json: \(genericModel)")
                return nil
            }
            model = sanitizedModel
        }
        
        guard let data = SentrySerialization.data(withJSONObject: model) else {
            SentrySDKLog.error("Failed to serialize \(name), reason: \(name) is not valid json: \(genericModel)")
            return nil
        }
        
        return data
    }
    
    func decode<T>(from data: Data, _ name: String) -> [String: T]? {
        guard let deserialized = SentrySerialization.deserializeDictionary(fromJsonData: data) else {
            SentrySDKLog.error("Failed to deserialize \(name), reason: data is not valid json")
            return nil
        }

        // `SentrySerialization` is a wrapper around `NSJSONSerialization` which returns any type of data (`id`).
        // It is the casted to a `NSDictionary`, which is then casted to a `[AnyHashable: Any]` in Swift.
        //
        // The responsibility of validating and casting the deserialized data from any data to a dictionary is delegated
        // to the `SentrySerialization` class.
        //
        // As this decode Tags method specifically returns a dictionary of strings, we need to ensure that
        // each value is a string.
        //
        // If the deserialized value is not a string, something clearly went wrong and we should discard the data.

        // Iterate through the deserialized dictionary and check if the type is a dictionary.
        // When all values are strings, we can safely cast it to `T` without allocating
        // additional memory (like when mapping values).
        for (key, value) in deserialized {
            guard value is T else {
                SentrySDKLog.error("Failed to deserialize \(name), reason: value for key \(key) is not a valid string")
                return nil
            }
        }

        return deserialized as? [String: T]
    }
}
