#import <Foundation/Foundation.h>

/**
 * A reason that defines why events were lost, see
 * https://develop.sentry.dev/sdk/client-reports/#envelope-item-payload.
 */
typedef NS_ENUM(NSUInteger, SentryDiscardReason) {
    kSentryDiscardReasonBeforeSend = 0,
    kSentryDiscardReasonEventProcessor = 1,
    kSentryDiscardReasonSampleRate = 2,
    kSentryDiscardReasonNetworkError = 3,
    kSentryDiscardReasonQueueOverflow = 4,
    kSentryDiscardReasonCacheOverflow = 5,
    kSentryDiscardReasonRateLimitBackoff = 6,
    kSentryDiscardReasonInsufficientData = 7
};

static DEPRECATED_MSG_ATTRIBUTE(
    "Use nameForSentryDiscardReason() instead.") NSString *_Nonnull const SentryDiscardReasonNames[]
    = { @"before_send", @"event_processor", @"sample_rate", @"network_error", @"queue_overflow",
          @"cache_overflow", @"ratelimit_backoff", @"insufficient_data" };
