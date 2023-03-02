#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SentryAppStartType) {
    SentryAppStartTypeWarm,
    SentryAppStartTypeCold,
    SentryAppStartTypeUnknown,
};

@interface SentryAppStartMeasurement : NSObject
SENTRY_NO_INIT

/**
 * Initializes SentryAppStartMeasurement with the given parameters.
 */
- (instancetype)initWithType:(SentryAppStartType)type
              appStartTimestamp:(NSDate *)appStartTimestamp
                       duration:(NSTimeInterval)duration
           runtimeInitTimestamp:(NSDate *)runtimeInitTimestamp
    didFinishLaunchingTimestamp:(NSDate *)didFinishLaunchingTimestamp;

/**
 * The type of the app start.
 */
@property (readonly, nonatomic, assign) SentryAppStartType type;

/**
 * How long the app start took. From appStartTimestamp to when the SDK creates the
 * AppStartMeasurement, which is done when the OS posts UIWindowDidBecomeVisibleNotification.
 */
@property (readonly, nonatomic, assign) NSTimeInterval duration;

/**
 * The timestamp when the app started, which is is the proces start timestamp.
 */
@property (readonly, nonatomic, strong) NSDate *appStartTimestamp;

/**
 * When the runtime was initialized / when SentryAppStartTracker is added to the Objective-C runtime
 */
@property (readonly, nonatomic, strong) NSDate *runtimeInitTimestamp;

/**
 * When OS posts UIApplicationDidFinishLaunchingNotification.
 */
@property (readonly, nonatomic, strong) NSDate *didFinishLaunchingTimestamp;

@end

NS_ASSUME_NONNULL_END
