import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
import UIKit

@objcMembers
class SentryTouchTracker: NSObject {
    
    private struct TouchEvent {
        let x: CGFloat
        let y: CGFloat
        let timestamp: TimeInterval
        let phase: TouchEventPhase
        
        var point: CGPoint {
            CGPoint(x: x, y: y)
        }
    }
    
    private class TouchInfo {
        let id: Int
        
        var startEvent: TouchEvent?
        var endEvent: TouchEvent?
        var moveEvents = [TouchEvent]()
        
        init(id: Int) {
            self.id = id
        }
    }
    
    /**
     * Using UITouch as a key because the touch is the same across events
     * for the same touch. As long we holding the reference no two UITouches
     * will ever have the same pointer.
     */
    private var trackedTouches = [UITouch: TouchInfo]()
    private var touchId = 1
    private let dateProvider: SentryCurrentDateProvider
    private let scale: CGAffineTransform
    
    init(dateProvider: SentryCurrentDateProvider, scale: Float) {
        self.dateProvider = dateProvider
        self.scale = CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale))
    }
    
    func trackTouchFrom(event: UIEvent) {
        guard let touches = event.allTouches else { return }
        for touch in touches {
            guard touch.phase == .began || touch.phase == .ended || touch.phase == .moved || touch.phase == .cancelled else { continue }
            let info = trackedTouches[touch] ?? TouchInfo(id: touchId++)
            let position = touch.location(in: nil).applying(scale)
            let newEvent = TouchEvent(x: position.x, y: position.y, timestamp: event.timestamp, phase: touch.phase.toRRWebTouchPhase())
            
            switch touch.phase {
            case .began:
                info.startEvent = newEvent
            case .ended, .cancelled:
                info.endEvent = newEvent
            case .moved:
                // If the distance between two points is smaller than 10 points, we don't record the second movement.
                // iOS event polling is fast and will capture any movement; we don't need this granularity for replay.
                if let last = info.moveEvents.last, touchesDelta(last.point, position) < 10 { continue }
                info.moveEvents.append(newEvent)
                debounceEvents(in: info)
            default:
                continue
            }
            
            trackedTouches[touch] = info
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
        trackedTouches = trackedTouches.filter { $0.value.endEvent == nil }
    }
    
    func replayEvents(from: Date, until: Date) -> [SentryRRWebEvent] {
        let uptime = dateProvider.systemUptime()
        let now = dateProvider.date()
        let startTimeInterval = uptime - now.timeIntervalSince(from)
        let endTimeInterval = uptime - now.timeIntervalSince(until)
        
        var result = [SentryRRWebEvent]()
        
        for info in trackedTouches.values {
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
