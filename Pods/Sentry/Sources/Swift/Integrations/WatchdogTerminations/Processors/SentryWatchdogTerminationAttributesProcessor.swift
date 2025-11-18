@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public class SentryWatchdogTerminationAttributesProcessor: NSObject {

    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let scopePersistentStore: SentryScopePersistentStore

    public init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopePersistentStore: SentryScopePersistentStore
    ) {
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.scopePersistentStore = scopePersistentStore

        super.init()

        clear()
    }
    
    public func clear() {
        SentrySDKLog.debug("Deleting all stored data in in persistent store")
        scopePersistentStore.deleteAllCurrentState()
    }

    public func setContext(_ context: [String: [String: Any]]?) {
        setData(data: context, field: .context) { [weak self] data in
            self?.scopePersistentStore.writeContextToDisk(context: data)
        }
    }
    
    public func setUser(_ user: User?) {
        setData(data: user, field: .user) { [weak self] data in
            self?.scopePersistentStore.writeUserToDisk(user: data)
        }
    }
    
    public func setDist(_ dist: String?) {
        setData(data: dist, field: .dist) { [weak self] data in
            self?.scopePersistentStore.writeDistToDisk(dist: data)
        }
    }
    
    public func setEnvironment(_ environment: String?) {
        setData(data: environment, field: .environment) { [weak self] data in
            self?.scopePersistentStore.writeEnvironmentToDisk(environment: data)
        }
    }
    
    public func setTags(_ tags: [String: String]?) {
        setData(data: tags, field: .tags) { [weak self] data in
            self?.scopePersistentStore.writeTagsToDisk(tags: data)
        }
    }
    
    public func setExtras(_ extras: [String: Any]?) {
        setData(data: extras, field: .extras) { [weak self] data in
            self?.scopePersistentStore.writeExtrasToDisk(extras: data)
        }
    }
    
    public func setFingerprint(_ fingerprint: [String]?) {
        setData(data: fingerprint, field: .fingerprint) { [weak self] data in
            self?.scopePersistentStore.writeFingerprintToDisk(fingerprint: data)
        }
    }
    
    // MARK: - Private
    private func setData<T>(data: T?, field: SentryScopeField, save: @escaping (T) -> Void) {
        SentrySDKLog.debug("Setting \(field.name) in background queue: \(String(describing: data))")
        dispatchQueueWrapper.dispatchAsync { [weak self] in
            guard let strongSelf = self else {
                SentrySDKLog.debug("Can not set \(field.name), reason: reference to processor is nil")
                return
            }
            guard let data = data else {
                SentrySDKLog.debug("Data for \(field.name) is nil, deleting active file.")
                strongSelf.scopePersistentStore.deleteCurrentFieldOnDisk(field: field)
                return
            }
            save(data)
        }
    }
}
