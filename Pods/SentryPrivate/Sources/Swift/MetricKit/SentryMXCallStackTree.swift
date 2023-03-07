import Foundation

#if os(iOS) || os(macOS)
/**
 * JSON specification of MXCallStackTree can be found here https://developer.apple.com/documentation/metrickit/mxcallstacktree/3552293-jsonrepresentation
 */
@objcMembers
public class SentryMXCallStackTree: NSObject, Codable {
    
    public let callStacks: [SentryMXCallStack]
    public let callStackPerThread: Bool
    
    public init(callStacks: [SentryMXCallStack], callStackPerThread: Bool) {
        self.callStacks = callStacks
        self.callStackPerThread = callStackPerThread
    }
    
    public static func from(data: Data) throws -> SentryMXCallStackTree {
        return try JSONDecoder().decode(SentryMXCallStackTree.self, from: data)
    }
}

@objcMembers
public class SentryMXCallStack: NSObject, Codable {
    public var threadAttributed: Bool?
    public var callStackRootFrames: [SentryMXFrame]
    
    public var flattenedRootFrames: [SentryMXFrame] {
        return callStackRootFrames.flatMap { [$0] + $0.frames }
    }

    public init(threadAttributed: Bool, rootFrames: [SentryMXFrame]) {
        self.threadAttributed = threadAttributed
        self.callStackRootFrames = rootFrames
    }
}

@objcMembers
public class SentryMXFrame: NSObject, Codable {
    public var binaryUUID: UUID
    public var offsetIntoBinaryTextSegment: Int
    public var binaryName: String?
    public var address: UInt64
    public var subFrames: [SentryMXFrame]?
    
    public var sampleCount: Int?
    
    public init(binaryUUID: UUID, offsetIntoBinaryTextSegment: Int, sampleCount: Int? = nil, binaryName: String? = nil, address: UInt64, subFrames: [SentryMXFrame]?) {
        self.binaryUUID = binaryUUID
        self.offsetIntoBinaryTextSegment = offsetIntoBinaryTextSegment
        self.sampleCount = sampleCount
        self.binaryName = binaryName
        self.address = address
        self.subFrames = subFrames
    }
    
    public var frames: [SentryMXFrame] {
        return (subFrames?.flatMap { [$0] + $0.frames } ?? [])
    }
    
    public var framesIncludingSelf: [SentryMXFrame] {
        return [self] + frames
    }
}

#endif
