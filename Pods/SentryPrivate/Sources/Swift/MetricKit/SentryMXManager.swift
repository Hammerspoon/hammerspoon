import Foundation

#if os(iOS) || os(macOS)

/**
 * We need to check if MetricKit is available for compatibility on iOS 12 and below. As there are no compiler directives for iOS versions we use canImport.
 */
#if canImport(MetricKit)
import MetricKit
#endif

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
@objc public protocol SentryMXManagerDelegate {
    
    func didReceiveCrashDiagnostic(_ diagnostic: MXCrashDiagnostic, callStackTree: SentryMXCallStackTree, timeStampBegin: Date, timeStampEnd: Date)
    
    func didReceiveDiskWriteExceptionDiagnostic(_ diagnostic: MXDiskWriteExceptionDiagnostic, callStackTree: SentryMXCallStackTree, timeStampBegin: Date, timeStampEnd: Date)
    
    func didReceiveCpuExceptionDiagnostic(_ diagnostic: MXCPUExceptionDiagnostic, callStackTree: SentryMXCallStackTree, timeStampBegin: Date, timeStampEnd: Date)
    
    func didReceiveHangDiagnostic(_ diagnostic: MXHangDiagnostic, callStackTree: SentryMXCallStackTree, timeStampBegin: Date, timeStampEnd: Date)
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
@objcMembers public class SentryMXManager: NSObject, MXMetricManagerSubscriber {
    
    let disableCrashDiagnostics: Bool
    
    public init(disableCrashDiagnostics: Bool = true) {
        self.disableCrashDiagnostics = disableCrashDiagnostics
    }

    public weak var delegate: SentryMXManagerDelegate?
    
    public func receiveReports() {
        let shared = MXMetricManager.shared
        shared.add(self)
    }
    
    public func pauseReports() {
        let shared = MXMetricManager.shared
        shared.remove(self)
    }
    
    public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        func actOn(callStackTree: MXCallStackTree, action: (SentryMXCallStackTree) -> Void) {
            guard let callStackTree = try? SentryMXCallStackTree.from(data: callStackTree.jsonRepresentation()) else {
                return
            }
            
            action(callStackTree)
        }
        
        payloads.forEach { payload in
            payload.crashDiagnostics?.forEach { diagnostic in
                if disableCrashDiagnostics {
                    return
                }
                actOn(callStackTree: diagnostic.callStackTree) { callStackTree in
                    delegate?.didReceiveCrashDiagnostic(diagnostic, callStackTree: callStackTree, timeStampBegin: payload.timeStampBegin, timeStampEnd: payload.timeStampEnd)
                }
            }
            
            payload.diskWriteExceptionDiagnostics?.forEach { diagnostic in
                actOn(callStackTree: diagnostic.callStackTree) { callStackTree in
                    delegate?.didReceiveDiskWriteExceptionDiagnostic(diagnostic, callStackTree: callStackTree, timeStampBegin: payload.timeStampBegin, timeStampEnd: payload.timeStampEnd)
                }
            }
            
            payload.cpuExceptionDiagnostics?.forEach { diagnostic in
                actOn(callStackTree: diagnostic.callStackTree) { callStackTree in
                    delegate?.didReceiveCpuExceptionDiagnostic(diagnostic, callStackTree: callStackTree, timeStampBegin: payload.timeStampBegin, timeStampEnd: payload.timeStampEnd)
                }
            }
            
            payload.hangDiagnostics?.forEach { diagnostic in
                actOn(callStackTree: diagnostic.callStackTree) { callStackTree in
                    delegate?.didReceiveHangDiagnostic(diagnostic, callStackTree: callStackTree, timeStampBegin: payload.timeStampBegin, timeStampEnd: payload.timeStampEnd)
                }
            }
        }
    }
}

#endif
