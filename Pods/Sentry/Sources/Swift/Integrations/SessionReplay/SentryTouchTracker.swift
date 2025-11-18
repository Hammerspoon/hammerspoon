import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

@objcMembers
@_spi(Private) public class SentryTouchTracker: NSObject {
    
    private struct TouchEvent {
        let x: CGFloat
        let y: CGFloat
        let timestamp: TimeInterval
        let phase: TouchEventPhase
        
        var point: CGPoint {
            CGPoint(x: x, y: y)
        }
    }
    
    private final class TouchInfo {
        let id: Int
        let identifier: ObjectIdentifier
        
        var startEvent: TouchEvent?
        var endEvent: TouchEvent?
        var moveEvents = [TouchEvent]()
        
        init(id: Int, identifier: ObjectIdentifier) {
            self.id = id
            self.identifier = identifier
        }
    }
    
    private struct ExtractedTouchData {
        let identifier: ObjectIdentifier
        let position: CGPoint
        let phase: UITouch.Phase
    }
    
    /**
     * Active touches tracked by ObjectIdentifier for O(1) lookup performance.
     * ObjectIdentifier can collide when UITouch memory is reused.
     */
    private var trackedTouches = [ObjectIdentifier: TouchInfo]()
    
    /**
     * Touches that were replaced in trackedTouches due to ObjectIdentifier collision.
     * Preserves events when UITouch memory is reused before flushFinishedEvents().
     */
    private var orphanedTouches = [TouchInfo]()
    
    private let dispatchQueue: SentryDispatchQueueWrapper
    private var touchId = 1
    private let dateProvider: SentryCurrentDateProvider
    private let scale: CGAffineTransform
    
    public init(dateProvider: SentryCurrentDateProvider, scale: Float, dispatchQueue: SentryDispatchQueueWrapper) {
        self.dateProvider = dateProvider
        self.scale = CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale))
        self.dispatchQueue = dispatchQueue
    }
    
    public convenience init(dateProvider: SentryCurrentDateProvider, scale: Float) {
        // SentryTouchTracker has it own dispatch queue instead of using the one
        // from Dependency container to avoid the bottleneck of sharing the same
        // queue with the rest of the SDK.
        self.init(dateProvider: dateProvider, scale: scale, dispatchQueue: SentryDispatchQueueWrapper())
    }
    
    public func trackTouchFrom(event: UIEvent) {
        guard let touches = event.allTouches else { return }
        let timestamp = event.timestamp
        
        // Extract touch data on the main thread before dispatching to background queue
        // to avoid accessing UIKit objects from a background thread
        let extractedTouches: [ExtractedTouchData] = touches.compactMap { touch in
            guard touch.phase == .began || touch.phase == .ended || touch.phase == .moved || touch.phase == .cancelled else { return nil }
            let position = touch.location(in: nil).applying(scale)
            // There is no way to uniquely identify a touch, so we use the ObjectIdentifier of the UITouch instance.
            // This is not a perfect solution, but it is the best we can do without holding references to UIKit objects.
            return ExtractedTouchData(identifier: ObjectIdentifier(touch), position: position, phase: touch.phase)
        }
        
        dispatchQueue.dispatchAsync { [self] in
            for extractedTouch in extractedTouches {
                processTouchEvent(extractedTouch, timestamp: timestamp)
            }
        }
    }
    
    private func processTouchEvent(_ extractedTouch: ExtractedTouchData, timestamp: TimeInterval) {
        let info: TouchInfo
        
        if extractedTouch.phase == .began {
            // Check for ObjectIdentifier collision - if touch already exists, orphan it
            if let existingTouch = trackedTouches[extractedTouch.identifier] {
                orphanedTouches.append(existingTouch)
            }
            
            // Create new TouchInfo for .began
            info = TouchInfo(id: touchId++, identifier: extractedTouch.identifier)
            trackedTouches[extractedTouch.identifier] = info
        } else {
            // O(1) dictionary lookup for non-.began phases
            if let existingInfo = trackedTouches[extractedTouch.identifier] {
                info = existingInfo
            } else {
                // Create new if not found (shouldn't happen, but handle gracefully)
                info = TouchInfo(id: touchId++, identifier: extractedTouch.identifier)
                trackedTouches[extractedTouch.identifier] = info
            }
        }
        
        let position = extractedTouch.position
        let newEvent = TouchEvent(x: position.x, y: position.y, timestamp: timestamp, phase: extractedTouch.phase.toRRWebTouchPhase())
        
        switch extractedTouch.phase {
        case .began:
            info.startEvent = newEvent
        case .ended, .cancelled:
            info.endEvent = newEvent
        case .moved:
            // If the distance between two points is smaller than 10 points, we don't record the second movement.
            // iOS event polling is fast and will capture any movement; we don't need this granularity for replay.
            if let last = info.moveEvents.last, touchesDelta(last.point, position) < 10 { return }
            info.moveEvents.append(newEvent)
            self.debounceEvents(in: info)
        default:
            return
        }
    }
    
    private func touchesDelta(_ lastTouch: CGPoint, _ newTouch: CGPoint) -> CGFloat {
        let dx = newTouch.x - lastTouch.x
        let dy = newTouch.y - lastTouch.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func debounceEvents(in touchInfo: TouchInfo) {
        guard touchInfo.moveEvents.count >= 3 else { return }
        let subset = touchInfo.moveEvents.suffix(3)
        if subset[subset.startIndex + 2].timestamp - subset[subset.startIndex + 1].timestamp > 0.5 {
            // Don't debounce if the last two touches have at least a 500 millisecond difference to show this pause in the replay.
            return
        }
        // If the last 3 touch points exist in a straight line, we don't need the middle point,
        // because the representation in the replay with 2 or 3 points will be the same.
        if arePointsCollinearSameDirection(subset[subset.startIndex].point, subset[subset.startIndex + 1].point, subset[subset.startIndex + 2].point) {
            touchInfo.moveEvents.remove(at: touchInfo.moveEvents.count - 2)
        }
    }
    
    private func arePointsCollinearSameDirection(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Bool {
        // In the case some tweeking in the tolerances is required
        // its possible to test this function in the following link: https://jsfiddle.net/dhiogorb/8owgh1pb/3/
        var abAngle = atan2(b.x - a.x, b.y - a.y)
        var bcAngle = atan2(c.x - b.x, c.y - b.y)

        if abAngle * bcAngle < 0 { return false; }

        abAngle += .pi
        bcAngle += .pi

        return abs(abAngle - bcAngle) < 0.05 || abs(abAngle - (2 * .pi - bcAngle)) < 0.05
    }
    
    func flushFinishedEvents() {
        SentrySDKLog.debug("[Session Replay] Flushing finished events")
        dispatchQueue.dispatchSync { [self] in
            trackedTouches = trackedTouches.filter { $0.value.endEvent == nil }
            orphanedTouches = orphanedTouches.filter { $0.endEvent == nil }
        }
    }
    
    func replayEvents(from: Date, until: Date) -> [SentryRRWebEvent] {
        let uptime = dateProvider.systemUptime()
        let now = dateProvider.date()
        let startTimeInterval = uptime - now.timeIntervalSince(from)
        let endTimeInterval = uptime - now.timeIntervalSince(until)
        
        var result = [SentryRRWebEvent]()
        
        var touches = [TouchInfo]()
        dispatchQueue.dispatchSync { [self] in
            // Include both active and orphaned touches to preserve all events
            touches = Array(trackedTouches.values) + orphanedTouches
        }
        
        for info in touches {
            if let infoStart = info.startEvent, infoStart.timestamp >= startTimeInterval && infoStart.timestamp <= endTimeInterval {
                result.append(RRWebTouchEvent(timestamp: now.addingTimeInterval(infoStart.timestamp - uptime), touchId: info.id, x: Float(infoStart.x), y: Float(infoStart.y), phase: .start))
            }
            
            let moveEvents: [TouchPosition] = info.moveEvents.compactMap { movement in
                movement.timestamp >= startTimeInterval && movement.timestamp <= endTimeInterval
                    ? TouchPosition(x: Float(movement.x), y: Float(movement.y), timestamp: now.addingTimeInterval(movement.timestamp - uptime))
                    : nil
            }
            
            if let lastMovement = moveEvents.last {
                result.append(RRWebMoveEvent(timestamp: lastMovement.timestamp, touchId: info.id, positions: moveEvents))
            }
            
            if let infoEnd = info.endEvent, infoEnd.timestamp >= startTimeInterval && infoEnd.timestamp <= endTimeInterval {
                result.append(RRWebTouchEvent(timestamp: now.addingTimeInterval(infoEnd.timestamp - uptime), touchId: info.id, x: Float(infoEnd.x), y: Float(infoEnd.y), phase: .end))
            }
        }

        return result.sorted { $0.timestamp.compare($1.timestamp) == .orderedAscending }
    }
}

private extension UITouch.Phase {
    func toRRWebTouchPhase() -> TouchEventPhase {
        switch self {
            case .began: return .start
            case .ended, .cancelled: return .end
            default: return .unknown
        }
    }
}

#endif
