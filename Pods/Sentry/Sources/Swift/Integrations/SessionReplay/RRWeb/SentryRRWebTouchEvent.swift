import Foundation

//Values defined in the RRWeb protocol
enum TouchEventPhase: Int {
    case unknown = 0
    case start   = 7
    case move    = 8
    case end     = 9
}

struct TouchPosition {
    let x: Float
    let y: Float
    let timestamp: Date
}

class RRWebTouchEvent: SentryRRWebEvent {
    
    init(timestamp: Date, touchId: Int, x: Float, y: Float, phase: TouchEventPhase) {
        super.init(type: .touch,
                   timestamp: timestamp,
                   data: [
                    "source": 2,
                    "pointerId": touchId,
                    "pointerType": 2,
                    "type": phase.rawValue,
                    "id": 0,
                    "x": x,
                    "y": y])
    }
}

class RRWebMoveEvent: SentryRRWebEvent {
    init(timestamp: Date, touchId: Int, positions: [TouchPosition]) {
        let positions: [[String: Any]] = positions.map({[
            "id": 0,
            "x": $0.x,
            "y": $0.y,
            "timeOffset": Int($0.timestamp.timeIntervalSince(timestamp) * 1_000)
        ]})
        super.init(type: .touch,
                   timestamp: timestamp,
                   data: [
                    "source": 6,
                    "pointerId": touchId,
                    "positions": positions
                   ])
    }
}
