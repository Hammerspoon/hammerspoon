#import "SentryUIKitMemoryWarningIntegration.h"
#import "SentryCrashInstallationReporter.h"
#import "SentryOptions.h"
#import "SentryLog.h"
#import "SentryEvent.h"
#import "SentrySDK.h"

#if SENTRY_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

@interface SentryUIKitMemoryWarningIntegration ()

@property(nonatomic, weak) SentryOptions *options;

@end

@implementation SentryUIKitMemoryWarningIntegration

- (void)installWithOptions:(nonnull SentryOptions *)options {
    self.options = options;
    [self trackMemoryPressureAsEvent];
}

- (void)trackMemoryPressureAsEvent {
#if SENTRY_HAS_UIKIT
    NSString __block *integrationName = NSStringFromClass(SentryUIKitMemoryWarningIntegration.class);
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelWarning];
    event.message = @"Memory Warning";
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification *notification) {
                                                    if (nil != [SentrySDK.currentHub getIntegration:integrationName]) {
                                                        [SentrySDK captureEvent:event];
                                                    }
                                                }];
#else
    [SentryLog logWithMessage:@"NO UIKit -> SentryUIKitMemoryWarningIntegration does nothing." andLevel:kSentryLogLevelDebug];
#endif
}

@end
