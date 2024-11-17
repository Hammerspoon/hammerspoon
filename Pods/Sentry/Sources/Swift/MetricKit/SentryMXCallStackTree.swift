import Foundation

#if os(iOS) || os(macOS)
/**
 * JSON specification of MXCallStackTree can be found here https://developer.apple.com/documentation/metrickit/mxcallstacktree/3552293-jsonrepresentation
 */
@objcMembers
class SentryMXCallStackTree: NSObject, Codable {
    
    let callStacks: [SentryMXCallStack]
    let callStackPerThread: Bool
    
    init(callStacks: [SentryMXCallStack], callStackPerThread: Bool) {
        self.callStacks = callStacks
        self.callStackPerThread = callStackPerThread
    }
    
    static func from(data: Data) throws -> SentryMXCallStackTree {
        return try JSONDecoder().decode(SentryMXCallStackTree.self, from: data)
    }
}

@objcMembers
class SentryMXCallStack: NSObject, Codable {
    var threadAttributed: Bool?
    var callStackRootFrames: [SentryMXFrame]
    
    var flattenedRootFrames: [SentryMXFrame] {
        return callStackRootFrames.flatMap { [$0] + $0.frames }
    }

    init(threadAttributed: Bool, rootFrames: [SentryMXFrame]) {
        self.threadAttributed = threadAttributed
        self.callStackRootFrames = rootFrames
    }
}

@objcMembers
class SentryMXFrame: NSObject, Codable {
    var binaryUUID: UUID
    var offsetIntoBinaryTextSegment: Int
    var binaryName: String?
    var address: UInt64
    var subFrames: [SentryMXFrame]?
    
    var sampleCount: Int?
    
    init(binaryUUID: UUID, offsetIntoBinaryTextSegment: Int, sampleCount: Int? = nil, binaryName: String? = nil, address: UInt64, subFrames: [SentryMXFrame]?) {
        self.binaryUUID = binaryUUID
        self.offsetIntoBinaryTextSegment = offsetIntoBinaryTextSegment
        self.sampleCount = sampleCount
        self.binaryName = binaryName
        self.address = address
        self.subFrames = subFrames
    }
    
    var frames: [SentryMXFrame] {
        return (subFrames?.flatMap { [$0] + $0.frames } ?? [])
    }
    
    var framesIncludingSelf: [SentryMXFrame] {
        return [self] + frames
    }
}

#endif
