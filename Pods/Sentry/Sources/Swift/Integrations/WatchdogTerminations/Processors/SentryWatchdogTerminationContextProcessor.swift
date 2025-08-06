@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
class SentryWatchdogTerminationContextProcessor: NSObject {

    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let scopeContextStore: SentryScopeContextPersistentStore

    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeContextStore: SentryScopeContextPersistentStore
    ) {
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.scopeContextStore = scopeContextStore

        super.init()

        clear()
    }

    func setContext(_ context: [String: [String: Any]]?) {
        SentryLog.debug("Setting context in background queue: \(context ?? [:])")
        dispatchQueueWrapper.dispatchAsync { [weak self] in
            guard let strongSelf = self else {
                SentryLog.debug("Can not set context, reason: reference to context processor is nil")
                return
            }
            guard let context = context else {
                SentryLog.debug("Context is nil, deleting active file.")
                strongSelf.scopeContextStore.deleteContextOnDisk()
                return
            }
            strongSelf.scopeContextStore.writeContextToDisk(context: context)
        }
    }

    func clear() {
        SentryLog.debug("Deleting context file in persistent store")
        scopeContextStore.deleteContextOnDisk()
    }
}
