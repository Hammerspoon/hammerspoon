#import "SentryDiscardReasonMapper.h"

NSString *const kSentryDiscardReasonNameBeforeSend = @"before_send";
NSString *const kSentryDiscardReasonNameEventProcessor = @"event_processor";
NSString *const kSentryDiscardReasonNameSampleRate = @"sample_rate";
NSString *const kSentryDiscardReasonNameNetworkError = @"network_error";
NSString *const kSentryDiscardReasonNameQueueOverflow = @"queue_overflow";
NSString *const kSentryDiscardReasonNameCacheOverflow = @"cache_overflow";
NSString *const kSentryDiscardReasonNameRateLimitBackoff = @"ratelimit_backoff";
NSString *const kSentryDiscardReasonNameInsufficientData = @"insufficient_data";

NSString *_Nonnull nameForSentryDiscardReason(SentryDiscardReason reason)
{
    switch (reason) {
    case kSentryDiscardReasonBeforeSend:
        return kSentryDiscardReasonNameBeforeSend;
    case kSentryDiscardReasonEventProcessor:
        return kSentryDiscardReasonNameEventProcessor;
    case kSentryDiscardReasonSampleRate:
        return kSentryDiscardReasonNameSampleRate;
    case kSentryDiscardReasonNetworkError:
        return kSentryDiscardReasonNameNetworkError;
    case kSentryDiscardReasonQueueOverflow:
        return kSentryDiscardReasonNameQueueOverflow;
    case kSentryDiscardReasonCacheOverflow:
        return kSentryDiscardReasonNameCacheOverflow;
    case kSentryDiscardReasonRateLimitBackoff:
        return kSentryDiscardReasonNameRateLimitBackoff;
    case kSentryDiscardReasonInsufficientData:
        return kSentryDiscardReasonNameInsufficientData;
    }
}
