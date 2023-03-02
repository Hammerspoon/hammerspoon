#import "SentryInternalDefines.h"
#import "SentryScope.h"
#import <Foundation/Foundation.h>
#import <SentryDebugMeta.h>
#import <SentryDependencyContainer.h>
#import <SentryEvent.h>
#import <SentryException.h>
#import <SentryFrame.h>
#import <SentryHexAddressFormatter.h>
#import <SentryMechanism.h>
#import <SentryMetricKitIntegration.h>
#import <SentrySDK+Private.h>
#import <SentryStacktrace.h>
#import <SentryThread.h>

#if SENTRY_HAS_METRIC_KIT

/**
 * We need to check if MetricKit is available for compatibility on iOS 12 and below. As there are no
 * compiler directives for iOS versions we use __has_include.
 */
#    if __has_include(<MetricKit/MetricKit.h>)
#        import <MetricKit/MetricKit.h>
#    endif

NS_ASSUME_NONNULL_BEGIN

@interface
SentryMetricKitIntegration ()

@property (nonatomic, strong, nullable) SentryMXManager *metricKitManager;
@property (nonatomic, strong) NSMeasurementFormatter *measurementFormatter;

@end

@implementation SentryMetricKitIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    self.metricKitManager = [SentryDependencyContainer sharedInstance].metricKitManager;
    self.metricKitManager.delegate = self;
    [self.metricKitManager receiveReports];
    self.measurementFormatter = [[NSMeasurementFormatter alloc] init];
    self.measurementFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    self.measurementFormatter.unitOptions = NSMeasurementFormatterUnitOptionsProvidedUnit;

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableMetricKit;
}

- (void)uninstall
{
    [self.metricKitManager pauseReports];
    self.metricKitManager.delegate = nil;
    self.metricKitManager = nil;
}

/**
 * Only for testing. We need to publish the iOS-Swift sample app to TestFlight for properly testing
 * this. We easily get MXCrashDiagnostic and so we can use them for validating symbolication. We
 * don't plan on releasing this. Instead, we are going to remove this code before releasing.
 */
- (void)didReceiveCrashDiagnostic:(MXCrashDiagnostic *)diagnostic
                    callStackTree:(SentryMXCallStackTree *)callStackTree
                   timeStampBegin:(NSDate *)timeStampBegin
                     timeStampEnd:(NSDate *)timeStampEnd
{
    NSString *exceptionValue =
        [NSString stringWithFormat:@"MachException Type:%@ Code:%@ Signal:%@",
                  diagnostic.exceptionType, diagnostic.exceptionCode, diagnostic.signal];

    [self captureMXEvent:callStackTree
                   handled:NO
                     level:kSentryLevelError
            exceptionValue:exceptionValue
             exceptionType:@"MXCrashDiagnostic"
        exceptionMechanism:@"MXCrashDiagnostic"
            timeStampBegin:timeStampBegin];
}

- (void)didReceiveCpuExceptionDiagnostic:(MXCPUExceptionDiagnostic *)diagnostic
                           callStackTree:(SentryMXCallStackTree *)callStackTree
                          timeStampBegin:(NSDate *)timeStampBegin
                            timeStampEnd:(NSDate *)timeStampEnd
{
    NSString *totalCPUTime =
        [self.measurementFormatter stringFromMeasurement:diagnostic.totalCPUTime];
    NSString *totalSampledTime =
        [self.measurementFormatter stringFromMeasurement:diagnostic.totalSampledTime];

    NSString *exceptionValue =
        [NSString stringWithFormat:@"MXCPUException totalCPUTime:%@ totalSampledTime:%@",
                  totalCPUTime, totalSampledTime];

    // Still need to figure out proper exception values and types.
    // This code is currently only there for testing with TestFlight.
    [self captureMXEvent:callStackTree
                   handled:YES
                     level:kSentryLevelWarning
            exceptionValue:exceptionValue
             exceptionType:SentryMetricKitCpuExceptionType
        exceptionMechanism:SentryMetricKitCpuExceptionMechanism
            timeStampBegin:timeStampBegin];
}

- (void)didReceiveDiskWriteExceptionDiagnostic:(MXDiskWriteExceptionDiagnostic *)diagnostic
                                 callStackTree:(SentryMXCallStackTree *)callStackTree
                                timeStampBegin:(NSDate *)timeStampBegin
                                  timeStampEnd:(NSDate *)timeStampEnd
{
    NSString *totalWritesCaused =
        [self.measurementFormatter stringFromMeasurement:diagnostic.totalWritesCaused];

    NSString *exceptionValue =
        [NSString stringWithFormat:@"MXDiskWriteException totalWritesCaused:%@", totalWritesCaused];

    // Still need to figure out proper exception values and types.
    // This code is currently only there for testing with TestFlight.
    [self captureMXEvent:callStackTree
                   handled:YES
                     level:kSentryLevelWarning
            exceptionValue:exceptionValue
             exceptionType:SentryMetricKitDiskWriteExceptionType
        exceptionMechanism:SentryMetricKitDiskWriteExceptionMechanism
            timeStampBegin:timeStampBegin];
}

- (void)didReceiveHangDiagnostic:(MXHangDiagnostic *)diagnostic
                   callStackTree:(SentryMXCallStackTree *)callStackTree
                  timeStampBegin:(NSDate *)timeStampBegin
                    timeStampEnd:(NSDate *)timeStampEnd
{
    NSString *hangDuration =
        [self.measurementFormatter stringFromMeasurement:diagnostic.hangDuration];

    NSString *exceptionValue = [NSString
        stringWithFormat:@"%@ hangDuration:%@", SentryMetricKitHangDiagnosticType, hangDuration];

    [self captureMXEvent:callStackTree
                   handled:YES
                     level:kSentryLevelWarning
            exceptionValue:exceptionValue
             exceptionType:SentryMetricKitHangDiagnosticType
        exceptionMechanism:SentryMetricKitHangDiagnosticMechanism
            timeStampBegin:timeStampBegin];
}

- (void)captureMXEvent:(SentryMXCallStackTree *)callStackTree
               handled:(BOOL)handled
                 level:(enum SentryLevel)level
        exceptionValue:(NSString *)exceptionValue
         exceptionType:(NSString *)exceptionType
    exceptionMechanism:(NSString *)exceptionMechanism
        timeStampBegin:(NSDate *)timeStampBegin
{
    // When receiving MXCrashDiagnostic the callStackPerThread was always true. In that case, the
    // MXCallStacks of the MXCallStackTree were individual threads, all belonging to the process
    // when the crash occurred. For MXCPUException, the callStackPerThread was always true. In that
    // case, the MXCallStacks stem from CPU-hungry multiple locations in the sample app during an
    // observation time of 90 seconds of one app run. It's a collection of stack traces that are
    // CPU-hungry. They could be from multiple threads or the same thread.
    if (callStackTree.callStackPerThread) {
        SentryEvent *event = [self createEvent:handled
                                         level:level
                                exceptionValue:exceptionValue
                                 exceptionType:exceptionType
                            exceptionMechanism:exceptionMechanism];

        event.timestamp = timeStampBegin;
        event.threads = [self convertToSentryThreads:callStackTree];

        SentryThread *crashedThread = event.threads[0];
        crashedThread.crashed = @(!handled);

        SentryException *exception = event.exceptions[0];
        exception.stacktrace = crashedThread.stacktrace;
        exception.threadId = crashedThread.threadId;

        event.debugMeta = [self extractDebugMetaFromMXCallStacks:callStackTree.callStacks];

        // The crash event can be way from the past. We don't want to impact the current session.
        // Therefore we don't call captureCrashEvent.
        [SentrySDK captureEvent:event];
    } else {
        for (SentryMXCallStack *callStack in callStackTree.callStacks) {

            for (SentryMXFrame *frame in callStack.callStackRootFrames) {

                SentryEvent *event = [self createEvent:handled
                                                 level:level
                                        exceptionValue:exceptionValue
                                         exceptionType:exceptionType
                                    exceptionMechanism:exceptionMechanism];
                event.timestamp = timeStampBegin;

                SentryThread *thread = [[SentryThread alloc] initWithThreadId:@0];
                thread.crashed = @(!handled);
                thread.stacktrace = [self
                    convertMXFramesToSentryStacktrace:frame.framesIncludingSelf.objectEnumerator];

                SentryException *exception = event.exceptions[0];
                exception.stacktrace = thread.stacktrace;
                exception.threadId = thread.threadId;

                event.threads = @[ thread ];
                event.debugMeta = [self extractDebugMetaFromMXFrames:frame.framesIncludingSelf];

                [SentrySDK captureEvent:event];
            }
        }
    }
}

- (SentryEvent *)createEvent:(BOOL)handled
                       level:(enum SentryLevel)level
              exceptionValue:(NSString *)exceptionValue
               exceptionType:(NSString *)exceptionType
          exceptionMechanism:(NSString *)exceptionMechanism
{
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:level];

    SentryException *exception = [[SentryException alloc] initWithValue:exceptionValue
                                                                   type:exceptionType];
    SentryMechanism *mechanism = [[SentryMechanism alloc] initWithType:exceptionMechanism];
    mechanism.handled = @(handled);
    mechanism.synthetic = @(YES);
    exception.mechanism = mechanism;
    event.exceptions = @[ exception ];

    return event;
}

- (NSArray<SentryThread *> *)convertToSentryThreads:(SentryMXCallStackTree *)callStackTree
{
    NSUInteger i = 0;
    NSMutableArray<SentryThread *> *threads = [NSMutableArray array];
    for (SentryMXCallStack *callStack in callStackTree.callStacks) {
        NSEnumerator<SentryMXFrame *> *frameEnumerator
            = callStack.flattenedRootFrames.objectEnumerator;
        // The MXFrames are in reversed order when callStackPerThread is true. The Apple docs don't
        // state that. This is an assumption based on observing MetricKit data.
        if (callStackTree.callStackPerThread) {
            frameEnumerator = [callStack.flattenedRootFrames reverseObjectEnumerator];
        }

        SentryStacktrace *stacktrace = [self convertMXFramesToSentryStacktrace:frameEnumerator];

        SentryThread *thread = [[SentryThread alloc] initWithThreadId:@(i)];
        thread.stacktrace = stacktrace;

        [threads addObject:thread];

        i++;
    }

    return threads;
}

- (SentryStacktrace *)convertMXFramesToSentryStacktrace:(NSEnumerator<SentryMXFrame *> *)mxFrames
{
    NSMutableArray<SentryFrame *> *frames = [NSMutableArray array];

    for (SentryMXFrame *mxFrame in mxFrames) {
        SentryFrame *frame = [[SentryFrame alloc] init];
        frame.package = mxFrame.binaryName;
        frame.instructionAddress = sentry_formatHexAddress(@(mxFrame.address));
        NSNumber *imageAddress = @(mxFrame.address - mxFrame.offsetIntoBinaryTextSegment);
        frame.imageAddress = sentry_formatHexAddress(imageAddress);

        [frames addObject:frame];
    }

    SentryStacktrace *stacktrace = [[SentryStacktrace alloc] initWithFrames:frames registers:@{}];

    return stacktrace;
}

/**
 * We must extract the debug images from the MetricKit stacktraces as the image addresses change
 * when you restart the app.
 */
- (NSArray<SentryDebugMeta *> *)extractDebugMetaFromMXCallStacks:
    (NSArray<SentryMXCallStack *> *)callStacks
{
    NSMutableDictionary<NSString *, SentryDebugMeta *> *debugMetas =
        [NSMutableDictionary dictionary];
    for (SentryMXCallStack *callStack in callStacks) {

        NSArray<SentryDebugMeta *> *callStackDebugMetas =
            [self extractDebugMetaFromMXFrames:callStack.flattenedRootFrames];

        for (SentryDebugMeta *debugMeta in callStackDebugMetas) {
            debugMetas[debugMeta.debugID] = debugMeta;
        }
    }

    return [debugMetas allValues];
}

- (NSArray<SentryDebugMeta *> *)extractDebugMetaFromMXFrames:(NSArray<SentryMXFrame *> *)mxFrames
{
    NSMutableDictionary<NSString *, SentryDebugMeta *> *debugMetas =
        [NSMutableDictionary dictionary];

    for (SentryMXFrame *mxFrame in mxFrames) {

        NSString *binaryUUID = [mxFrame.binaryUUID UUIDString];
        if (debugMetas[binaryUUID]) {
            continue;
        }

        SentryDebugMeta *debugMeta = [[SentryDebugMeta alloc] init];
        debugMeta.type = SentryDebugImageType;
        debugMeta.debugID = binaryUUID;
        debugMeta.codeFile = mxFrame.binaryName;

        NSNumber *imageAddress = @(mxFrame.address - mxFrame.offsetIntoBinaryTextSegment);
        debugMeta.imageAddress = sentry_formatHexAddress(imageAddress);

        debugMetas[debugMeta.debugID] = debugMeta;
    }

    return [debugMetas allValues];
}

@end

NS_ASSUME_NONNULL_END

#endif

NS_ASSUME_NONNULL_BEGIN

@implementation
SentryEvent (MetricKit)

- (BOOL)isMetricKitEvent
{
    if (self.exceptions == nil || self.exceptions.count != 1) {
        return NO;
    }

    NSArray<NSString *> *metricKitMechanisms = @[
        SentryMetricKitDiskWriteExceptionMechanism, SentryMetricKitCpuExceptionMechanism,
        SentryMetricKitHangDiagnosticMechanism, @"MXCrashDiagnostic"
    ];

    SentryException *exception = self.exceptions[0];
    if (exception.mechanism != nil &&
        [metricKitMechanisms containsObject:exception.mechanism.type]) {
        return YES;
    } else {
        return NO;
    }
}

@end

NS_ASSUME_NONNULL_END
