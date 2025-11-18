#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

@class SentryId;
@class SentryProfileOptions;
@class SentrySpanId;
@class SentryClient;
@class SentryDispatchQueueWrapper;
@class SentryTransactionContext;

NS_ASSUME_NONNULL_BEGIN

// The functions in this file exist to bridge ObjectiveC++ to Swift. When building with Swift
// Package Manager you can’t import Swift into ObjectiveC++ so instead that code calls plain C
// functions in this file which then uses Swift in their implementation.

#ifdef __cplusplus
extern "C" {
#endif

#if !SDK_V9
BOOL sentry_isContinuousProfilingEnabled(SentryClient *client);
#endif // !SDK_V9
BOOL sentry_isContinuousProfilingV2Enabled(SentryClient *client);
BOOL sentry_isProfilingCorrelatedToTraces(SentryClient *client);
SentryProfileOptions *_Nullable sentry_getProfiling(SentryClient *client);
NSString *sentry_stringFromSentryID(SentryId *sentryID);
NSDate *sentry_getDate(void);
uint64_t sentry_getSystemTime(void);
SentryId *sentry_getSentryId(void);
SentryProfileOptions *sentry_getSentryProfileOptions(void);
BOOL sentry_isTraceLifecycle(SentryProfileOptions *options);
float sentry_sessionSampleRate(SentryProfileOptions *options);
BOOL sentry_profileAppStarts(SentryProfileOptions *options);
SentrySpanId *_Nullable sentry_getParentSpanID(SentryTransactionContext *context);
SentryId *sentry_getTraceID(SentryTransactionContext *context);
BOOL sentry_isNotSampled(SentryTransactionContext *context);
void sentry_dispatchAsync(SentryDispatchQueueWrapper *wrapper, dispatch_block_t block);
void sentry_dispatchAsyncOnMain(SentryDispatchQueueWrapper *wrapper, dispatch_block_t block);
void sentry_addObserver(id observer, SEL selector, NSNotificationName name, _Nullable id object);
void sentry_removeObserver(id observer);
void sentry_postNotification(NSNotification *notification);
id sentry_addObserverForName(NSNotificationName name, dispatch_block_t block);
NSTimer *sentry_scheduledTimer(NSTimeInterval interval, BOOL repeats, dispatch_block_t block);
NSTimer *sentry_scheduledTimerWithTarget(
    NSTimeInterval interval, id target, SEL selector, _Nullable id userInfo, BOOL repeats);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
