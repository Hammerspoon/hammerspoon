import Foundation

@objc
@_spi(Private) public class SentryNSTimerFactory: NSObject {
    
    @objc @discardableResult
    @_spi(Private) public func scheduledTimer(withTimeInterval interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Void) -> Timer {
        if !Thread.isMainThread {
            let warningText = "Timers must be scheduled from the main thread, or they may never fire. See the attribute on the declaration in NSTimer.h. See https://stackoverflow.com/questions/8304702/how-do-i-create-a-nstimer-on-a-background-thread for more info."
            SentrySDKLog.warning(warningText)
            assertionFailure(warningText)
        }
        return Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats, block: block)
    }
    
    @objc @discardableResult
    @_spi(Private) public func scheduledTimer(withTimeInterval ti: TimeInterval, target aTarget: Any, selector aSelector: Selector, userInfo: Any?, repeats yesOrNo: Bool) -> Timer {
        if !Thread.isMainThread {
            let warningText = "Timers must be scheduled from the main thread, or they may never fire. See the attribute on the declaration in NSTimer.h. See https://stackoverflow.com/questions/8304702/how-do-i-create-a-nstimer-on-a-background-thread for more info."
            SentrySDKLog.warning(warningText)
            assertionFailure(warningText)
        }
        return Timer.scheduledTimer(timeInterval: ti, target: aTarget, selector: aSelector, userInfo: userInfo, repeats: yesOrNo)
    }
}
