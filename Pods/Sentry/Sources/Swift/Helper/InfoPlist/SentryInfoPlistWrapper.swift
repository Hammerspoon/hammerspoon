@objc @_spi(Private) public class SentryInfoPlistWrapper: NSObject, SentryInfoPlistWrapperProvider {

    private let bundle: Bundle

    public override init() {
        // We can not use defaults in the initializer because this class is used from Objective-C
        self.bundle = Bundle.main
        super.init()
    }

    public init(bundle: Bundle) {
        self.bundle = bundle
        super.init()
    }

    // MARK: - Bridge to ObjC

    public func getAppValueBoolean(for key: String, errorPtr errPtr: NSErrorPointer) -> Bool {
        do {
            guard let value = try getAppValue(for: key, type: Bool.self) else {
                throw SentryInfoPlistError.keyNotFound(key: key)
            }
            return value
        } catch {
            errPtr?.pointee = error as NSError
            return false
        }
    }

    public func getAppValueString(for key: String) throws -> String {
        guard let value = try getAppValue(for: key, type: String.self) else {
            throw SentryInfoPlistError.keyNotFound(key: key)
        }
        return value
    }

    // MARK: - Swift Implementation

    private func getAppValue<T>(for key: String, type: T.Type) throws -> T? {
        // As soon as this class is not consumed from Objective-C anymore, we can use this method directly to reduce
        // unnecessary duplicate code. In addition this method can be adapted to use `SentryInfoPlistKey` as the type
        // of the parameter `key`
        guard let infoDictionary = bundle.infoDictionary else {
            throw SentryInfoPlistError.mainInfoPlistNotFound
        }
        guard let value = infoDictionary[key] else {
            return nil
        }
        guard let typedValue = value as? T else {
            throw SentryInfoPlistError.unableToCastValue(key: key, value: value, type: T.self)
        }
        return typedValue
    }
}
