#import "PrivateSentrySDKOnly.h"
#import "SentryDebugImageProvider.h"
#import "SentrySDK+Private.h"
#import "SentrySerialization.h"
#import <Foundation/Foundation.h>
#import <SentryFramesTracker.h>

@interface
PrivateSentrySDKOnly ()

@property (nonatomic, strong) SentryDebugImageProvider *debugImageProvider;

@end

@implementation PrivateSentrySDKOnly

static SentryOnAppStartMeasurementAvailable _onAppStartMeasurmentAvailable;
static BOOL _appStartMeasurementHybridSDKMode = NO;

- (instancetype)init
{
    if (self = [super init]) {
        _debugImageProvider = [[SentryDebugImageProvider alloc] init];
    }
    return self;
}

+ (void)storeEnvelope:(SentryEnvelope *)envelope
{
    [SentrySDK storeEnvelope:envelope];
}

+ (void)captureEnvelope:(SentryEnvelope *)envelope
{
    [SentrySDK captureEnvelope:envelope];
}

+ (nullable SentryEnvelope *)envelopeWithData:(NSData *)data
{
    return [SentrySerialization envelopeWithData:data];
}

- (NSArray<SentryDebugMeta *> *)getDebugImages
{
    return [self.debugImageProvider getDebugImages];
}

+ (nullable SentryAppStartMeasurement *)appStartMeasurement
{
    return [SentrySDK getAppStartMeasurement];
}

+ (SentryOnAppStartMeasurementAvailable)onAppStartMeasurementAvailable
{
    return _onAppStartMeasurmentAvailable;
}

+ (void)setOnAppStartMeasurementAvailable:
    (SentryOnAppStartMeasurementAvailable)onAppStartMeasurementAvailable
{
    _onAppStartMeasurmentAvailable = onAppStartMeasurementAvailable;
}

+ (BOOL)appStartMeasurementHybridSDKMode
{
    return _appStartMeasurementHybridSDKMode;
}

+ (void)setAppStartMeasurementHybridSDKMode:(BOOL)appStartMeasurementHybridSDKMode
{
    _appStartMeasurementHybridSDKMode = appStartMeasurementHybridSDKMode;
}

#if SENTRY_HAS_UIKIT

+ (BOOL)isFramesTrackingRunning
{
    return [SentryFramesTracker sharedInstance].isRunning;
}

+ (SentryScreenFrames *)currentScreenFrames
{
    return [SentryFramesTracker sharedInstance].currentFrames;
}

#endif

@end
