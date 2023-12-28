#import "SentryAppStartMeasurement.h"

#if SENTRY_UIKIT_AVAILABLE

#    import "NSDate+SentryExtras.h"
#    import "SentryLog.h"
#    import <Foundation/Foundation.h>

@implementation SentryAppStartMeasurement
#    if SENTRY_HAS_UIKIT
{
    SentryAppStartType _type;
    BOOL _isPreWarmed;
    NSTimeInterval _duration;
    NSDate *_appStartTimestamp;
    NSDate *_runtimeInitTimestamp;
    NSDate *_moduleInitializationTimestamp;
    NSDate *_didFinishLaunchingTimestamp;
}
#    endif // SENTRY_HAS_UIKIT

- (instancetype)initWithType:(SentryAppStartType)type
              appStartTimestamp:(NSDate *)appStartTimestamp
                       duration:(NSTimeInterval)duration
           runtimeInitTimestamp:(NSDate *)runtimeInitTimestamp
    didFinishLaunchingTimestamp:(NSDate *)didFinishLaunchingTimestamp
{
#    if SENTRY_HAS_UIKIT
    return [self initWithType:type
                          isPreWarmed:NO
                    appStartTimestamp:appStartTimestamp
                             duration:duration
                 runtimeInitTimestamp:runtimeInitTimestamp
        moduleInitializationTimestamp:[NSDate dateWithTimeIntervalSince1970:0]
          didFinishLaunchingTimestamp:didFinishLaunchingTimestamp];
#    else
    SENTRY_LOG_DEBUG(@"SentryAppStartMeasurement only works with UIKit enabled. Ensure you're "
                     @"using the right configuration of Sentry that links UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}

- (instancetype)initWithType:(SentryAppStartType)type
                      isPreWarmed:(BOOL)isPreWarmed
                appStartTimestamp:(NSDate *)appStartTimestamp
                         duration:(NSTimeInterval)duration
             runtimeInitTimestamp:(NSDate *)runtimeInitTimestamp
    moduleInitializationTimestamp:(NSDate *)moduleInitializationTimestamp
      didFinishLaunchingTimestamp:(NSDate *)didFinishLaunchingTimestamp
{
#    if SENTRY_HAS_UIKIT
    if (self = [super init]) {
        _type = type;
        _isPreWarmed = isPreWarmed;
        _appStartTimestamp = appStartTimestamp;
        _duration = duration;
        _runtimeInitTimestamp = runtimeInitTimestamp;
        _moduleInitializationTimestamp = moduleInitializationTimestamp;
        _didFinishLaunchingTimestamp = didFinishLaunchingTimestamp;
    }

    return self;
#    else
    SENTRY_LOG_DEBUG(@"SentryAppStartMeasurement only works with UIKit enabled. Ensure you're "
                     @"using the right configuration of Sentry that links UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}

@end

#endif // SENTRY_UIKIT_AVAILABLE
