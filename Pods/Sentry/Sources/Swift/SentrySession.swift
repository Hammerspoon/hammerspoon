@_implementationOnly import _SentryPrivate
import Foundation

@objc @_spi(Private) public enum SentrySessionStatus: UInt {
    init(internalStatus: InternalSentrySessionStatus) {
        switch internalStatus {
        case .sentrySessionStatusOk:
            self = .ok
        case .sentrySessionStatusExited:
            self = .exited
        case .sentrySessionStatusCrashed:
            self = .crashed
        case .sentrySessionStatusAbnormal:
            fallthrough
        @unknown default:
            self = .abnormal
        }
    }

    case ok       = 0
    case exited   = 1
    case crashed  = 2
    case abnormal = 3
}

/// The SDK uses SentrySession to inform Sentry about release and project associated project health.
@objc @_spi(Private) public class SentrySession: NSObject, NSCopying {
    
    // MARK: Private
    
    let session: SentrySessionInternal

    @available(*, unavailable, message: "Use init(releaseName:distinctId:) instead.")
    private override init() {
        fatalError("Not Implemented")
    }
    
    private init(session: SentrySessionInternal) {
        self.session = session
    }
    
    // MARK: Internal

    /// Designated initializer.
    @objc public init(releaseName: String, distinctId: String) {
        session = SentrySessionInternal(releaseName: releaseName, distinctId: distinctId)
    }

    /**
     * Initializes @c SentrySession from a JSON object.
     * @param jsonObject The @c jsonObject containing the session.
     * @return The @c SentrySession or @c nil if @c jsonObject contains an error.
     */
    @objc(initWithJSONObject:) public init?(jsonObject: [String: Any]) {
        guard let session = SentrySessionInternal(jsonObject: jsonObject) else {
            return nil
        }
        self.session = session
    }

    @objc(endSessionExitedWithTimestamp:)
    public func endExited(withTimestamp timestamp: Date) {
        session.endSessionExited(withTimestamp: timestamp)
    }

    @objc(endSessionCrashedWithTimestamp:)
    public func endCrashed(withTimestamp timestamp: Date) {
        session.endSessionCrashed(withTimestamp: timestamp)
    }

    @objc(endSessionAbnormalWithTimestamp:)
    public func endAbnormal(withTimestamp timestamp: Date) {
        session.endSessionAbnormal(withTimestamp: timestamp)
    }

    @objc public func incrementErrors() {
        session.incrementErrors()
    }

    @objc public var sessionId: UUID {
        session.sessionId
    }
    @objc public var started: Date {
        session.started
    }
    @objc public var status: SentrySessionStatus {
        SentrySessionStatus(internalStatus: session.status)
    }
    @objc public var errors: UInt {
        get { session.errors }
        set { session.errors = newValue }
    }
    @objc public var sequence: UInt {
        session.sequence
    }
    @objc public var distinctId: String {
        session.distinctId
    }

    @objc public var flagInit: NSNumber? {
        session.flagInit
    }

    @objc public var timestamp: Date? {
        session.timestamp
    }
    @objc public var duration: NSNumber? {
        session.duration
    }

    @objc public var releaseName: String? {
        session.releaseName
    }
    @objc public var environment: String? {
        get { session.environment }
        set { session.environment = newValue }
    }
    @objc public var user: User? {
        get { session.user }
        set { session.user = newValue }
    }
    @objc public var abnormalMechanism: String? {
        get { session.abnormalMechanism }
        set { session.abnormalMechanism = newValue }
    }

    @objc public func serialize() -> [String: Any] {
        session.serialize()
    }
    
    @objc public func setFlagInit() {
        session.setFlagInit()
    }

    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = session.safeCopy(with: zone)
        return SentrySession(session: copy)
    }
}
