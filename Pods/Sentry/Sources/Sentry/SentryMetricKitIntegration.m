#import "SentryInternalDefines.h"
#import "SentryScope.h"
#import <Foundation/Foundation.h>
#import <SentryDebugMeta.h>
#import <SentryDependencyContainer.h>
#import <SentryEvent.h>
#import <SentryException.h>
#import <SentryFrame.h>
#import <SentryHexAddressFormatter.h>
#import <SentryInAppLogic.h>
#import <SentryLog.h>
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

@interface SentryMXExceptionParams : NSObject

@property (nonatomic, assign) BOOL handled;
@property (nonatomic, assign) SentryLevel level;
@property (nonatomic, copy) NSString *exceptionValue;
@property (nonatomic, copy) NSString *exceptionType;
@property (nonatomic, copy) NSString *exceptionMechanism;
@property (nonatomic, copy) NSDate *timeStampBegin;

@end

@implementation SentryMXExceptionParams

@end

@interface
SentryMetricKitIntegration ()

@property (nonatomic, strong, nullable) SentryMXManager *metricKitManager;
@property (nonatomic, strong) NSMeasurementFormatter *measurementFormatter;
@property (nonatomic, strong) SentryInAppLogic *inAppLogic;

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
    self.inAppLogic = [[SentryInAppLogic alloc] initWithInAppIncludes:options.inAppIncludes
                                                        inAppExcludes:options.inAppExcludes];

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

    SentryMXExceptionParams *params = [[SentryMXExceptionParams alloc] init];
    params.handled = NO;
    params.level = kSentryLevelError;
    params.exceptionValue = exceptionValue;
    params.exceptionType = @"MXCrashDiagnostic";
    params.exceptionMechanism = @"MXCrashDiagnostic";
    params.timeStampBegin = timeStampBegin;

    [self captureMXEvent:callStackTree params:params];
}

- (void)didReceiveCpuExceptionDiagnostic:(MXCPUExceptionDiagnostic *)diagnostic
                           callStackTree:(SentryMXCallStackTree *)callStackTree
                          timeStampBegin:(NSDate *)timeStampBegin
                            timeStampEnd:(NSDate *)timeStampEnd
{
    // MXCPUExceptionDiagnostics call stacks point to hot spots in code and aren't organized per
    // thread. See https://developer.apple.com/videos/play/wwdc2020/10078/?time=224
    if (callStackTree.callStackPerThread) {
        SENTRY_LOG_WARN(@"MXCPUExceptionDiagnostics aren't expected to have call stacks per "
                        @"thread. Ignoring it.");
        return;
    }

    NSString *totalCPUTime =
        [self.measurementFormatter stringFromMeasurement:diagnostic.totalCPUTime];
    NSString *totalSampledTime =
        [self.measurementFormatter stringFromMeasurement:diagnostic.totalSampledTime];

    NSString *exceptionValue =
        [NSString stringWithFormat:@"MXCPUException totalCPUTime:%@ totalSampledTime:%@",
                  totalCPUTime, totalSampledTime];

    // Still need to figure out proper exception values and types.
    // This code is currently only there for testing with TestFlight.
    SentryMXExceptionParams *params = [[SentryMXExceptionParams alloc] init];
    params.handled = YES;
    params.level = kSentryLevelWarning;
    params.exceptionValue = exceptionValue;
    params.exceptionType = SentryMetricKitCpuExceptionType;
    params.exceptionMechanism = SentryMetricKitCpuExceptionMechanism;
    params.timeStampBegin = timeStampBegin;

    [self captureMXEvent:callStackTree params:params];
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

    SentryMXExceptionParams *params = [[SentryMXExceptionParams alloc] init];
    params.handled = YES;
    params.level = kSentryLevelWarning;
    params.exceptionValue = exceptionValue;
    params.exceptionType = SentryMetricKitDiskWriteExceptionType;
    params.exceptionMechanism = SentryMetricKitDiskWriteExceptionMechanism;
    params.timeStampBegin = timeStampBegin;

    [self captureMXEvent:callStackTree params:params];
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

    SentryMXExceptionParams *params = [[SentryMXExceptionParams alloc] init];
    params.handled = YES;
    params.level = kSentryLevelWarning;
    params.exceptionValue = exceptionValue;
    params.exceptionType = SentryMetricKitHangDiagnosticType;
    params.exceptionMechanism = SentryMetricKitHangDiagnosticMechanism;
    params.timeStampBegin = timeStampBegin;

    [self captureMXEvent:callStackTree params:params];
}

- (void)captureMXEvent:(SentryMXCallStackTree *)callStackTree
                params:(SentryMXExceptionParams *)params
{
    // When receiving MXCrashDiagnostic the callStackPerThread was always true. In that case, the
    // MXCallStacks of the MXCallStackTree were individual threads, all belonging to the process
    // when the crash occurred. For MXCPUException, the callStackPerThread was always false. In that
    // case, the MXCallStacks stem from CPU-hungry multiple locations in the sample app during an
    // observation time of 90 seconds of one app run. It's a collection of stack traces that are
    // CPU-hungry.
    if (callStackTree.callStackPerThread) {
        SentryEvent *event = [self createEvent:params];

        event.timestamp = params.timeStampBegin;
        event.threads = [self convertToSentryThreads:callStackTree];

        SentryThread *crashedThread = event.threads[0];
        crashedThread.crashed = @(!params.handled);

        SentryException *exception = event.exceptions[0];
        exception.stacktrace = crashedThread.stacktrace;
        exception.threadId = crashedThread.threadId;

        event.debugMeta = [self extractDebugMetaFromMXCallStacks:callStackTree.callStacks];

        // The crash event can be way from the past. We don't want to impact the current session.
        // Therefore we don't call captureCrashEvent.
        [SentrySDK captureEvent:event];
    } else {
        for (SentryMXCallStack *callStack in callStackTree.callStacks) {
            [self buildAndCaptureMXEventFor:callStack.callStackRootFrames params:params];
        }
    }
}

/**
 * If callStackPerThread is false, MetricKit organizes the stacktraces in a tree structure. See
 * https://developer.apple.com/videos/play/wwdc2020/10078/?time=224. The stacktrace consists of the
 * last sibbling leaf frame plus its ancestors.
 *
 * The algorithm adds all frames to a list until it finds a leaf frame being the last sibling. Then
 * it reports that frame with its siblings and ancestors as a stacktrace.
 *
 * In the following example, the algorithm starts with frame 0, continues until frame 6, and reports
 * a stacktrace. Then it pops all sibling, goes back up to frame 3, and continues the search.
 *
 * | frame 0 |
 *      | frame 1 |
 *          | frame 2 |
 *          | frame 3 |
 *              | frame 4 |
 *              | frame 5 |
 *              | frame 6 |     -> stack trace consists of [0, 1, 3, 4, 5, 6]
 *          | frame 7 |
 *          | frame 8 |         -> stack trace consists of [0, 1, 2, 3, 7, 8]
 *      | frame 9 |             -> stack trace consists of [0, 1, 9]
 * | frame 10 |
 *      | frame 11 |
 *          | frame 12 |
 *          | frame 13 |    -> stack trace consists of [10, 11, 12, 13]
 */
- (void)buildAndCaptureMXEventFor:(NSArray<SentryMXFrame *> *)rootFrames
                           params:(SentryMXExceptionParams *)params
{
    for (SentryMXFrame *rootFrame in rootFrames) {
        NSMutableArray<SentryMXFrame *> *stackTraceFrames = [NSMutableArray array];
        NSMutableSet<NSNumber *> *processedFrameAddresses = [NSMutableSet set];
        NSMutableDictionary<NSNumber *, SentryMXFrame *> *addressesToParentFrames =
            [NSMutableDictionary dictionary];

        SentryMXFrame *currentFrame = rootFrame;
        [stackTraceFrames addObject:currentFrame];

        while (stackTraceFrames.count > 0) {
            currentFrame = [stackTraceFrames lastObject];
            [processedFrameAddresses addObject:@(currentFrame.address)];

            for (SentryMXFrame *subFrame in currentFrame.subFrames) {
                addressesToParentFrames[@(subFrame.address)] = currentFrame;
            }
            SentryMXFrame *parentFrame = addressesToParentFrames[@(currentFrame.address)];

            SentryMXFrame *firstUnprocessedSibling =
                [self getFirstUnprocessedSubFrames:parentFrame.subFrames
                           processedFrameAddresses:processedFrameAddresses];

            BOOL lastUnprocessedSibling = firstUnprocessedSibling == nil;
            BOOL noChildren = currentFrame.subFrames.count == 0;

            if (noChildren && lastUnprocessedSibling) {
                [self captureEventNotPerThread:stackTraceFrames params:params];

                // Pop all siblings
                for (int i = 0; i < parentFrame.subFrames.count; i++) {
                    [stackTraceFrames removeLastObject];
                }
            } else {
                SentryMXFrame *nonProcessedSubFrame =
                    [self getFirstUnprocessedSubFrames:currentFrame.subFrames
                               processedFrameAddresses:processedFrameAddresses];

                // Keep adding sub frames
                if (nonProcessedSubFrame != nil) {
                    [stackTraceFrames addObject:nonProcessedSubFrame];
                } // Keep adding siblings
                else if (firstUnprocessedSibling != nil) {
                    [stackTraceFrames addObject:firstUnprocessedSibling];
                } // Keep popping
                else {
                    [stackTraceFrames removeLastObject];
                }
            }
        }
    }
}

- (nullable SentryMXFrame *)getFirstUnprocessedSubFrames:(NSArray<SentryMXFrame *> *)subFrames
                                 processedFrameAddresses:
                                     (NSSet<NSNumber *> *)processedFrameAddresses
{
    return [subFrames filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(
                                                      SentryMXFrame *frame,
                                                      NSDictionary<NSString *, id> *bindings) {
        return ![processedFrameAddresses containsObject:@(frame.address)];
    }]].firstObject;
}

- (void)captureEventNotPerThread:(NSArray<SentryMXFrame *> *)frames
                          params:(SentryMXExceptionParams *)params
{
    SentryEvent *event = [self createEvent:params];
    event.timestamp = params.timeStampBegin;

    SentryThread *thread = [[SentryThread alloc] initWithThreadId:@0];
    thread.crashed = @(!params.handled);
    thread.stacktrace = [self convertMXFramesToSentryStacktrace:frames.objectEnumerator];

    SentryException *exception = event.exceptions[0];
    exception.stacktrace = thread.stacktrace;
    exception.threadId = thread.threadId;

    event.threads = @[ thread ];
    event.debugMeta = [self extractDebugMetaFromMXFrames:frames];

    [SentrySDK captureEvent:event];
}

- (SentryEvent *)createEvent:(SentryMXExceptionParams *)params
{
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:params.level];

    SentryException *exception = [[SentryException alloc] initWithValue:params.exceptionValue
                                                                   type:params.exceptionType];
    SentryMechanism *mechanism = [[SentryMechanism alloc] initWithType:params.exceptionMechanism];
    mechanism.handled = @(params.handled);
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
        frame.inApp = @([self.inAppLogic isInApp:mxFrame.binaryName]);
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
