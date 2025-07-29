#if __has_include(<Sentry/PrivatesHeader.h>)
#    import <Sentry/PrivatesHeader.h>
#else
#    import "PrivatesHeader.h"
#endif

#if __has_include(<Sentry/SentryScreenFrames.h>)
#    import <Sentry/SentryScreenFrames.h>
#else
#    import "SentryScreenFrames.h"
#endif

@class SentryDebugMeta;
@class SentryScreenFrames;
@class SentryAppStartMeasurement;
@class SentryOptions;
@class SentryBreadcrumb;
@class SentryUser;
@class SentryEnvelope;
@class SentryId;
@class SentrySpanId;
@class SentrySessionReplayIntegration;
@class UIView;

@protocol SentryReplayBreadcrumbConverter;
@protocol SentryViewScreenshotProvider;
@protocol SentryRedactOptions;

NS_ASSUME_NONNULL_BEGIN

/**
 * A callback to be notified when the @c AppStartMeasurement is available.
 */
typedef void (^SentryOnAppStartMeasurementAvailable)(
    SentryAppStartMeasurement *_Nullable appStartMeasurement);

/**
 * @warning This class is reserved for hybrid SDKs. Methods may be changed, renamed or removed
 * without notice. If you want to use one of these methods here please open up an issue and let us
 * know.
 * @note The name of this class is supposed to be a bit weird and ugly. The name starts with private
 * on purpose so users don't see it in code completion when typing Sentry. We also add only at the
 * end to make it more obvious you shouldn't use it.
 */
@interface PrivateSentrySDKOnly : NSObject

/**
 * For storing an envelope synchronously to disk.
 */
+ (void)storeEnvelope:(SentryEnvelope *)envelope;

+ (void)captureEnvelope:(SentryEnvelope *)envelope;

/**
 * Create an envelope from @c NSData. Needed for example by Flutter.
 */
+ (nullable SentryEnvelope *)envelopeWithData:(NSData *)data;

/**
 * Returns the current list of debug images. Be aware that the @c SentryDebugMeta is actually
 * describing a debug image.
 * @warning This assumes a crash has occurred and attempts to read the crash information from each
 * image's data segment, which may not be present or be invalid if a crash has not actually
 * occurred. To avoid this, use the new @c +[getDebugImagesCrashed:] instead.
 */
+ (NSArray<SentryDebugMeta *> *)getDebugImages;

/**
 * Returns the current list of debug images. Be aware that the @c SentryDebugMeta is actually
 * describing a debug image.
 * @param isCrash @c YES if we're collecting binary images for a crash report, @c NO if we're
 * gathering them for other backtrace information, like a performance transaction. If this is for a
 * crash, each image's data section crash info is also included.
 */
+ (NSArray<SentryDebugMeta *> *)getDebugImagesCrashed:(BOOL)isCrash;

/**
 * Override SDK information.
 */
+ (void)setSdkName:(NSString *)sdkName andVersionString:(NSString *)versionString;

/**
 * Override SDK information.
 */
+ (void)setSdkName:(NSString *)sdkName;

/**
 * Retrieves the SDK name
 */
+ (NSString *)getSdkName;

/**
 * Retrieves the SDK version string
 */
+ (NSString *)getSdkVersionString;

/**
 * Add a package to the SDK packages
 */
+ (void)addSdkPackage:(NSString *)name version:(NSString *)version;

/**
 * Retrieves extra context
 */
+ (NSDictionary *)getExtraContext;

/**
 * Allows Hybrids SDKs to thread-safe set the current trace.
 */
+ (void)setTrace:(SentryId *)traceId spanId:(SentrySpanId *)spanId;

#if SENTRY_TARGET_PROFILING_SUPPORTED
/**
 * Start a profiler session associated with the given @c SentryId.
 * @return The system time when the profiler session started.
 */
+ (uint64_t)startProfilerForTrace:(SentryId *)traceId;

/**
 * Collect a profiler session data associated with the given @c SentryId.
 * This also discards the profiler.
 */
+ (nullable NSMutableDictionary<NSString *, id> *)collectProfileBetween:(uint64_t)startSystemTime
                                                                    and:(uint64_t)endSystemTime
                                                               forTrace:(SentryId *)traceId;

/**
 * Discard profiler session data associated with the given @c SentryId.
 * This only needs to be called in case you haven't collected the profile (and don't intend to).
 */
+ (void)discardProfilerForTrace:(SentryId *)traceId;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

@property (class, nullable, nonatomic, copy)
    SentryOnAppStartMeasurementAvailable onAppStartMeasurementAvailable;

@property (class, nullable, nonatomic, readonly) SentryAppStartMeasurement *appStartMeasurement;

@property (class, nonatomic, readonly, copy) NSString *installationID;

@property (class, nonatomic, readonly, copy) SentryOptions *options;

/**
 * If enabled, the SDK won't send the app start measurement with the first transaction. Instead, if
 * @c enableAutoPerformanceTracing is enabled, the SDK measures the app start and then calls
 * @c onAppStartMeasurementAvailable. Furthermore, the SDK doesn't set all values for the app start
 * measurement because the HybridSDKs initialize the Cocoa SDK too late to receive all
 * notifications. Instead, the SDK sets the @c appStartDuration to @c 0 and the
 * @c didFinishLaunchingTimestamp to @c timeIntervalSinceReferenceDate.
 * @note Default is @c NO.
 */
@property (class, nonatomic, assign) BOOL appStartMeasurementHybridSDKMode;

#if SENTRY_UIKIT_AVAILABLE
/**
 * Allows hybrid SDKs to enable frame tracking measurements despite other options.
 * @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
 * configurations even when targeting iOS or tvOS platforms.
 */
@property (class, nonatomic, assign) BOOL framesTrackingMeasurementHybridSDKMode;

/**
 * @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
 * configurations even when targeting iOS or tvOS platforms.
 */
@property (class, nonatomic, assign, readonly) BOOL isFramesTrackingRunning;

/**
 * @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
 * configurations even when targeting iOS or tvOS platforms.
 */
@property (class, nonatomic, assign, readonly) SentryScreenFrames *currentScreenFrames;

/**
 * @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
 * configurations even when targeting iOS or tvOS platforms.
 */
+ (NSArray<NSData *> *)captureScreenshots;

/**
 * @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
 * configurations even when targeting iOS or tvOS platforms.
 */
+ (NSData *)captureViewHierarchy;

/**
 * Allow Hybrids SDKs to set the current Screen.
 */
+ (void)setCurrentScreen:(NSString *)screenName;

#endif // SENTRY_UIKIT_AVAILABLE

#if SENTRY_TARGET_REPLAY_SUPPORTED

/**
 * Return an instance of SentryRedactOptions with given option
 * To be used from SentrySwiftUI, which cannot access the private
 * `SentryRedactOptions` class.
 */
+ (UIView *)sessionReplayMaskingOverlay:(id<SentryRedactOptions>)options;

/**
 * Configure session replay with different breadcrumb converter
 * and screeshot provider. Used by the Hybrid SDKs.
 * Passing nil will keep the previous value.
 */
+ (void)configureSessionReplayWith:(nullable id<SentryReplayBreadcrumbConverter>)breadcrumbConverter
                screenshotProvider:(nullable id<SentryViewScreenshotProvider>)screenshotProvider;

+ (void)captureReplay;
+ (NSString *__nullable)getReplayId;
+ (void)addReplayIgnoreClasses:(NSArray<Class> *_Nonnull)classes;
+ (void)addReplayRedactClasses:(NSArray<Class> *_Nonnull)classes;
+ (void)setIgnoreContainerClass:(Class _Nonnull)containerClass;
+ (void)setRedactContainerClass:(Class _Nonnull)containerClass;
+ (void)setReplayTags:(NSDictionary<NSString *, id> *)tags;

#endif
+ (nullable NSDictionary<NSString *, id> *)appStartMeasurementWithSpans;

+ (SentryUser *)userWithDictionary:(NSDictionary *)dictionary;

+ (SentryBreadcrumb *)breadcrumbWithDictionary:(NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END
