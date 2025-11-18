import Foundation

@objc @_spi(Private) public protocol SentryNSNotificationCenterWrapper {
    func addObserver(_ observer: Any, selector aSelector: Selector, name aName: NSNotification.Name?, object anObject: Any?)
    @objc(addObserverForName:object:queue:usingBlock:)
    func addObserver(forName name: NSNotification.Name?, object obj: Any?, queue: OperationQueue?, using block: @Sendable @escaping (Notification) -> Void) -> NSObjectProtocol
    func removeObserver(_ observer: Any, name aName: NSNotification.Name?, object anObject: Any?)
    @objc(postNotification:)
    func post(_ notification: Notification)
}

@objc @_spi(Private) extension NotificationCenter: SentryNSNotificationCenterWrapper { }
