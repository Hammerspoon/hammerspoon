/**
 * In hybrid SDKs, we might initialize the Cocoa SDK after the hybrid engine is ready. So, we may
 * register the didBecomeActive notification after the OS posts it. Therefore the hybrid SDKs can
 * post this internal notification after initializing the Cocoa SDK. Hybrid SDKs must only post this
 * notification if they are running in the foreground.
 */
static NSString *const SentryHybridSdkDidBecomeActiveNotificationName
    = @"SentryHybridSdkDidBecomeActive";
