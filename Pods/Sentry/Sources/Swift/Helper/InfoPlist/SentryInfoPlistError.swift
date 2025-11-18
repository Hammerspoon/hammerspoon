enum SentryInfoPlistError: Error {
    case mainInfoPlistNotFound
    case keyNotFound(key: String)
    case unableToCastValue(key: String, value: Any, type: Any.Type)
}
