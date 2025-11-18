@_implementationOnly import _SentryPrivate
import Foundation

@objc
@objcMembers
@_spi(Private) public class SentryLogBatcher: NSObject {
    
    private let client: SentryClient
    private let flushTimeout: TimeInterval
    private let maxBufferSizeBytes: Int
    private let dispatchQueue: SentryDispatchQueueWrapper
    
    internal let options: Options

    // All mutable state is accessed from the same serial dispatch queue.
    
    // Every logs data is added sepratley. They are flushed together in an envelope.
    private var encodedLogs: [Data] = []
    private var encodedLogsSize: Int = 0
    private var timerWorkItem: DispatchWorkItem?

    /// Initializes a new SentryLogBatcher.
    /// - Parameters:
    ///   - client: The SentryClient to use for sending logs
    ///   - flushTimeout: The timeout interval after which buffered logs will be flushed
    ///   - maxBufferSizeBytes: The maximum buffer size in bytes before triggering an immediate flush
    ///   - dispatchQueue: A **serial** dispatch queue wrapper for thread-safe access to mutable state
    ///
    /// - Important: The `dispatchQueue` parameter MUST be a serial queue to ensure thread safety.
    ///              Passing a concurrent queue will result in undefined behavior and potential data races.
    @_spi(Private) public init(
        client: SentryClient,
        flushTimeout: TimeInterval,
        maxBufferSizeBytes: Int,
        dispatchQueue: SentryDispatchQueueWrapper
    ) {
        self.client = client
        self.options = client.options
        self.flushTimeout = flushTimeout
        self.maxBufferSizeBytes = maxBufferSizeBytes
        self.dispatchQueue = dispatchQueue
        super.init()
    }
    
    /// Convenience initializer with default flush timeout and buffer size.
    /// - Parameters:
    ///   - client: The SentryClient to use for sending logs
    ///   - dispatchQueue: A **serial** dispatch queue wrapper for thread-safe access to mutable state
    ///
    /// - Important: The `dispatchQueue` parameter MUST be a serial queue to ensure thread safety.
    ///              Passing a concurrent queue will result in undefined behavior and potential data races.
    @_spi(Private) public convenience init(client: SentryClient, dispatchQueue: SentryDispatchQueueWrapper) {
        self.init(
            client: client,
            flushTimeout: 5,
            maxBufferSizeBytes: 1_024 * 1_024, // 1MB
            dispatchQueue: dispatchQueue
        )
    }
    
    @_spi(Private) func add(_ log: SentryLog) {
        dispatchQueue.dispatchAsync { [weak self] in
            self?.encodeAndBuffer(log: log)
        }
    }
    
    // Captures batched logs sync and returns the duration.
    @discardableResult
    @_spi(Private) func captureLogs() -> TimeInterval {
        let startTimeNs = SentryDefaultCurrentDateProvider.getAbsoluteTime()
        dispatchQueue.dispatchSync { [weak self] in
            self?.performCaptureLogs()
        }
        let endTimeNs = SentryDefaultCurrentDateProvider.getAbsoluteTime()
        return TimeInterval(endTimeNs - startTimeNs) / 1_000_000_000.0 // Convert nanoseconds to seconds
    }

    // Helper

    // Only ever call this from the serial dispatch queue.
    private func encodeAndBuffer(log: SentryLog) {
        do {
            let encodedLog = try encodeToJSONData(data: log)
            
            let encodedLogsWereEmpty = encodedLogs.isEmpty
            
            encodedLogs.append(encodedLog)
            encodedLogsSize += encodedLog.count
            
            if encodedLogsSize >= maxBufferSizeBytes {
                performCaptureLogs()
            } else if encodedLogsWereEmpty && timerWorkItem == nil {
                startTimer()
            }
        } catch {
            SentrySDKLog.error("Failed to encode log: \(error)")
        }
    }
    
    // Only ever call this from the serial dispatch queue.
    private func startTimer() {
        let timerWorkItem = DispatchWorkItem { [weak self] in
            SentrySDKLog.debug("SentryLogBatcher: Timer fired, calling performFlush().")
            self?.performCaptureLogs()
        }
        self.timerWorkItem = timerWorkItem
        dispatchQueue.dispatch(after: flushTimeout, workItem: timerWorkItem)
    }

    // Only ever call this from the serial dispatch queue.
    private func performCaptureLogs() {
        // Reset logs on function exit
        defer {
            encodedLogs.removeAll()
            encodedLogsSize = 0
        }
        
        // Reset timer state
        timerWorkItem?.cancel()
        timerWorkItem = nil
        
        guard encodedLogs.count > 0 else {
            SentrySDKLog.debug("SentryLogBatcher: No logs to flush.")
            return
        }

        // Create the payload.
        
        var payloadData = Data()
        payloadData.append(Data("{\"items\":[".utf8))
        let separator = Data(",".utf8)
        for (index, encodedLog) in encodedLogs.enumerated() {
            if index > 0 {
                payloadData.append(separator)
            }
            payloadData.append(encodedLog)
        }
        payloadData.append(Data("]}".utf8))
        
        // Send the payload.
        
        client.captureLogsData(payloadData, with: NSNumber(value: encodedLogs.count))
    }
}
