#import <Foundation/Foundation.h>

#import "SentryDefines.h"

@class SentryEnvelope, SentryDebugMeta, SentryAppStartMeasurement, SentryScreenFrames;

NS_ASSUME_NONNULL_BEGIN

/**
 * A callback to be notified when the AppStartMeasurement is available.
 */
typedef void (^SentryOnAppStartMeasurementAvailable)(
    SentryAppStartMeasurement *_Nullable appStartMeasurement);

/**
 * ATTENTION: This class is reserved for hybrid SDKs. Methods may be changed, renamed or removed
 * without notice. If you want to use one of these methods here please open up an issue and let us
 * know.
 *
 * The name of this class is supposed to be a bit weird and ugly. The name starts with private on
 * purpose so users don't see it in code completion when typing Sentry. We also add only at the end
 * to make it more obvious you shouldn't use it.
 */
@interface PrivateSentrySDKOnly : NSObject

/**
 * For storing an envelope synchronously to disk.
 */
+ (void)storeEnvelope:(SentryEnvelope *)envelope;

+ (void)captureEnvelope:(SentryEnvelope *)envelope;

/**
 * Create an envelope from NSData. Needed for example by Flutter.
 */
+ (nullable SentryEnvelope *)envelopeWithData:(NSData *)data;

/**
 * Returns the current list of debug images. Be aware that the SentryDebugMeta is actually
 * describing a debug image. This class should be renamed to SentryDebugImage in a future version.
 */
- (NSArray<SentryDebugMeta *> *)getDebugImages;

@property (class, nullable, nonatomic, copy)
    SentryOnAppStartMeasurementAvailable onAppStartMeasurementAvailable;

@property (class, nullable, nonatomic, readonly) SentryAppStartMeasurement *appStartMeasurement;

/**
 * If enabled, the SDK won't send the app start measurement with the first transaction. Instead, if
 * enableAutoPerformanceTracking is enabled, the SDK measures the app start and then calls
 * onAppStartMeasurementAvailable. Furthermore, the SDK doesn't set all values for the app start
 * measurement because the HybridSDKs initialize the Cocoa SDK too late to receive all
 * notifications. Instead, the SDK sets the appStartDuration to 0 and the
 * didFinishLaunchingTimestamp to timeIntervalSinceReferenceDate. Default is NO.
 */
@property (class, nonatomic, assign) BOOL appStartMeasurementHybridSDKMode;

#if SENTRY_HAS_UIKIT
@property (class, nonatomic, assign, readonly) BOOL isFramesTrackingRunning;
@property (class, nonatomic, assign, readonly) SentryScreenFrames *currentScreenFrames;
#endif

@end

NS_ASSUME_NONNULL_END
