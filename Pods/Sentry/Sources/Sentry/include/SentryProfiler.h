#import "SentryCompiler.h"
#import "SentryProfilingConditionals.h"
#import "SentrySpan.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT
@class SentryFramesTracker;
#endif // SENTRY_HAS_UIKIT
@class SentryHub;
@class SentryNSProcessInfoWrapper;
@class SentryProfilesSamplerDecision;
@class SentryScreenFrames;
@class SentryEnvelope;
@class SentrySpanId;
@class SentrySystemWrapper;
@class SentryTransaction;

#if SENTRY_TARGET_PROFILING_SUPPORTED

typedef NS_ENUM(NSUInteger, SentryProfilerTruncationReason) {
    SentryProfilerTruncationReasonNormal,
    SentryProfilerTruncationReasonTimeout,
    SentryProfilerTruncationReasonAppMovedToBackground,
};

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN const int kSentryProfilerFrequencyHz;
SENTRY_EXTERN NSString *const kTestStringConst;

SENTRY_EXTERN NSString *const kSentryProfilerSerializationKeySlowFrameRenders;
SENTRY_EXTERN NSString *const kSentryProfilerSerializationKeyFrozenFrameRenders;
SENTRY_EXTERN NSString *const kSentryProfilerSerializationKeyFrameRates;

SENTRY_EXTERN_C_BEGIN

/*
 * Parses a symbol that is returned from `backtrace_symbols()`, which encodes information
 * like the frame index, image name, function name, and offset in a single string. e.g.
 * For the input:
 * 2   UIKitCore                           0x00000001850d97ac -[UIFieldEditor
 * _fullContentInsetsFromFonts] + 160 This function would return: -[UIFieldEditor
 * _fullContentInsetsFromFonts]
 *
 * If the format does not match the expected format, this returns the input string.
 */
NSString *parseBacktraceSymbolsFunctionName(const char *symbol);

NSString *profilerTruncationReasonName(SentryProfilerTruncationReason reason);

SENTRY_EXTERN_C_END

@interface SentryProfiler : NSObject

/**
 * Start the profiler, if it isn't already running, for the span with the provided ID. If it's
 * already running, it will track the new span as well.
 */
+ (void)startForSpanID:(SentrySpanId *)spanID hub:(SentryHub *)hub;

/**
 * Report that a span ended to the profiler so it can update bookkeeping and if it was the last
 * concurrent span being profiled, stops the profiler.
 */
+ (void)stopProfilingSpan:(id<SentrySpan>)span;

/**
 * Certain transactions may be dropped by the SDK at the time they are ended, when we've already
 * been tracking them for profiling. This allows them to be removed from bookkeeping and finish
 * profile if necessary.
 */
+ (void)dropTransaction:(SentryTransaction *)transaction;
;

/**
 * After the SDK creates a transaction for a span, link it to this profile. If it was the last
 * concurrent span being profiled, capture an envelope with the profile data and clean up the
 * profiler.
 */
+ (void)linkTransaction:(SentryTransaction *)transaction;

+ (BOOL)isRunning;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
