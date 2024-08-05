#import "SentryAppStartMeasurement.h"

#if SENTRY_UIKIT_AVAILABLE

#    import "SentryDateUtils.h"
#    import "SentryLog.h"
#    import <Foundation/Foundation.h>

@implementation SentryAppStartTypeToString
+ (NSString *)convert:(SentryAppStartType)type
{
    switch (type) {
    case SentryAppStartTypeWarm:
        return @"warm";
    case SentryAppStartTypeCold:
        return @"cold";
    case SentryAppStartTypeUnknown:
        return @"unknown";
    }
}
@end

@implementation SentryAppStartMeasurement
#    if SENTRY_HAS_UIKIT
{
    SentryAppStartType _type;
    BOOL _isPreWarmed;
    NSTimeInterval _duration;
    NSDate *_appStartTimestamp;
    uint64_t _runtimeInitSystemTimestamp;
    NSDate *_runtimeInitTimestamp;
    NSDate *_moduleInitializationTimestamp;
    NSDate *_sdkStartTimestamp;
    NSDate *_didFinishLaunchingTimestamp;
}
#    endif // SENTRY_HAS_UIKIT

- (instancetype)initWithType:(SentryAppStartType)type
                      isPreWarmed:(BOOL)isPreWarmed
                appStartTimestamp:(NSDate *)appStartTimestamp
       runtimeInitSystemTimestamp:(uint64_t)runtimeInitSystemTimestamp
                         duration:(NSTimeInterval)duration
             runtimeInitTimestamp:(NSDate *)runtimeInitTimestamp
    moduleInitializationTimestamp:(NSDate *)moduleInitializationTimestamp
                sdkStartTimestamp:(NSDate *)sdkStartTimestamp
      didFinishLaunchingTimestamp:(NSDate *)didFinishLaunchingTimestamp
{
#    if SENTRY_HAS_UIKIT
    if (self = [super init]) {
        _type = type;
        _isPreWarmed = isPreWarmed;
        _appStartTimestamp = appStartTimestamp;
        _runtimeInitSystemTimestamp = runtimeInitSystemTimestamp;
        _duration = duration;
        _runtimeInitTimestamp = runtimeInitTimestamp;
        _moduleInitializationTimestamp = moduleInitializationTimestamp;
        _sdkStartTimestamp = sdkStartTimestamp;
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
