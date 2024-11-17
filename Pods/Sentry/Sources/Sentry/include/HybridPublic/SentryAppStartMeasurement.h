#import "PrivatesHeader.h"

#if SENTRY_UIKIT_AVAILABLE

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SentryAppStartType) {
    SentryAppStartTypeWarm,
    SentryAppStartTypeCold,
    SentryAppStartTypeUnknown,
};

// This is need for serialization in HybridSDKs
@interface SentryAppStartTypeToString : NSObject
SENTRY_NO_INIT
+ (NSString *_Nonnull)convert:(SentryAppStartType)type;
@end

/**
 * @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
 * configurations even when targeting iOS or tvOS platforms.
 */
@interface SentryAppStartMeasurement : NSObject
SENTRY_NO_INIT

/**
 * Initializes SentryAppStartMeasurement with the given parameters.
 */
- (instancetype)initWithType:(SentryAppStartType)type
                      isPreWarmed:(BOOL)isPreWarmed
                appStartTimestamp:(NSDate *)appStartTimestamp
       runtimeInitSystemTimestamp:(uint64_t)runtimeInitSystemTimestamp
                         duration:(NSTimeInterval)duration
             runtimeInitTimestamp:(NSDate *)runtimeInitTimestamp
    moduleInitializationTimestamp:(NSDate *)moduleInitializationTimestamp
                sdkStartTimestamp:(NSDate *)sdkStartTimestamp
      didFinishLaunchingTimestamp:(NSDate *)didFinishLaunchingTimestamp;

/**
 * The type of the app start.
 */
@property (readonly, nonatomic, assign) SentryAppStartType type;

@property (readonly, nonatomic, assign) BOOL isPreWarmed;

/**
 * How long the app start took. From appStartTimestamp to when the SDK creates the
 * AppStartMeasurement, which is done when the OS posts UIWindowDidBecomeVisibleNotification and
 * when `enablePerformanceV2` is enabled when the app draws it's first frame.
 */
@property (readonly, nonatomic, assign) NSTimeInterval duration;

/**
 * The timestamp when the app started, which is the process start timestamp and for prewarmed app
 * starts the moduleInitializationTimestamp.
 */
@property (readonly, nonatomic, strong) NSDate *appStartTimestamp;

/**
 * Similar to @c appStartTimestamp, but in number of nanoseconds, and retrieved with
 * @c clock_gettime_nsec_np / @c mach_absolute_time if measured from module initialization time.
 */
@property (readonly, nonatomic, assign) uint64_t runtimeInitSystemTimestamp;

/**
 * When the runtime was initialized / when SentryAppStartTracker is added to the Objective-C runtime
 */
@property (readonly, nonatomic, strong) NSDate *runtimeInitTimestamp;

/**
 * When application main function is called.
 */
@property (readonly, nonatomic, strong) NSDate *moduleInitializationTimestamp;

/**
 * When the SentrySDK start method is called.
 */
@property (readonly, nonatomic, strong) NSDate *sdkStartTimestamp;

/**
 * When OS posts UIApplicationDidFinishLaunchingNotification.
 */
@property (readonly, nonatomic, strong) NSDate *didFinishLaunchingTimestamp;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_UIKIT_AVAILABLE
