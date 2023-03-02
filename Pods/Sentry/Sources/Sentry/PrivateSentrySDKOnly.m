#import "PrivateSentrySDKOnly.h"
#import "SentryClient.h"
#import "SentryDebugImageProvider.h"
#import "SentryHub+Private.h"
#import "SentryInstallation.h"
#import "SentryMeta.h"
#import "SentrySDK+Private.h"
#import "SentrySerialization.h"
#import "SentryViewHierarchy.h"
#import <SentryDependencyContainer.h>
#import <SentryFramesTracker.h>
#import <SentryScreenshot.h>

@implementation PrivateSentrySDKOnly

static SentryOnAppStartMeasurementAvailable _onAppStartMeasurementAvailable;
static BOOL _appStartMeasurementHybridSDKMode = NO;
#if SENTRY_HAS_UIKIT
static BOOL _framesTrackingMeasurementHybridSDKMode = NO;
#endif

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

+ (NSArray<SentryDebugMeta *> *)getDebugImages
{
    return [[SentryDependencyContainer sharedInstance].debugImageProvider getDebugImages];
}

+ (nullable SentryAppStartMeasurement *)appStartMeasurement
{
    return [SentrySDK getAppStartMeasurement];
}

+ (NSString *)installationID
{
    return [SentryInstallation id];
}

+ (SentryOptions *)options
{
    SentryOptions *options = [[SentrySDK currentHub] client].options;
    if (options != nil) {
        return options;
    }
    return [[SentryOptions alloc] init];
}

+ (SentryOnAppStartMeasurementAvailable)onAppStartMeasurementAvailable
{
    return _onAppStartMeasurementAvailable;
}

+ (void)setOnAppStartMeasurementAvailable:
    (SentryOnAppStartMeasurementAvailable)onAppStartMeasurementAvailable
{
    _onAppStartMeasurementAvailable = onAppStartMeasurementAvailable;
}

+ (BOOL)appStartMeasurementHybridSDKMode
{
    return _appStartMeasurementHybridSDKMode;
}

+ (void)setAppStartMeasurementHybridSDKMode:(BOOL)appStartMeasurementHybridSDKMode
{
    _appStartMeasurementHybridSDKMode = appStartMeasurementHybridSDKMode;
}

+ (void)setSdkName:(NSString *)sdkName andVersionString:(NSString *)versionString
{
    SentryMeta.sdkName = sdkName;
    SentryMeta.versionString = versionString;
}

+ (void)setSdkName:(NSString *)sdkName
{
    SentryMeta.sdkName = sdkName;
}

+ (NSString *)getSdkName
{
    return SentryMeta.sdkName;
}

+ (NSString *)getSdkVersionString
{
    return SentryMeta.versionString;
}

#if SENTRY_HAS_UIKIT

+ (BOOL)framesTrackingMeasurementHybridSDKMode
{
    return _framesTrackingMeasurementHybridSDKMode;
}

+ (void)setFramesTrackingMeasurementHybridSDKMode:(BOOL)framesTrackingMeasurementHybridSDKMode
{
    _framesTrackingMeasurementHybridSDKMode = framesTrackingMeasurementHybridSDKMode;
}

+ (BOOL)isFramesTrackingRunning
{
    return [SentryFramesTracker sharedInstance].isRunning;
}

+ (SentryScreenFrames *)currentScreenFrames
{
    return [SentryFramesTracker sharedInstance].currentFrames;
}

+ (NSArray<NSData *> *)captureScreenshots
{
    return [SentryDependencyContainer.sharedInstance.screenshot takeScreenshots];
}

+ (NSData *)captureViewHierarchy
{
    return [SentryDependencyContainer.sharedInstance.viewHierarchy fetchViewHierarchy];
}

#endif

@end
