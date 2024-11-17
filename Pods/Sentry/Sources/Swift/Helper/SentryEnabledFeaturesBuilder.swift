import Foundation

@objcMembers class SentryEnabledFeaturesBuilder: NSObject {
    
    static func getEnabledFeatures(options: Options) -> [String] {
        
        var features: [String] = []
        
        if options.enableCaptureFailedRequests {
            features.append("captureFailedRequests")
        }
        
        if options.enablePerformanceV2 {
            features.append("performanceV2")
        }
        
        if options.enableTimeToFullDisplayTracing {
            features.append("timeToFullDisplayTracing")
        }

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
        if options.enableAppLaunchProfiling {
            features.append("appLaunchProfiling")
        }
#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)

#if os(iOS) || os(tvOS)
#if canImport(UIKit) && !SENTRY_NO_UIKIT
        if options.enablePreWarmedAppStartTracing {
            features.append("preWarmedAppStartTracing")
        }
#endif // canImport(UIKit)
#endif // os(iOS) || os(tvOS)
        
        if options.swiftAsyncStacktraces {
            features.append("swiftAsyncStacktraces")
        }
        
        if options.enableMetrics {
            features.append("metrics")
        }
        
        return features
    }
}
