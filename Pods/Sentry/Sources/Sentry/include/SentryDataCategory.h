#import <Foundation/Foundation.h>

/**
 * The data category rate limits: https://develop.sentry.dev/sdk/rate-limiting/#definitions and
 * client reports: https://develop.sentry.dev/sdk/client-reports/#envelope-item-payload. Be aware
 * that these categories are different from the envelope item types.
 */
typedef NS_ENUM(NSUInteger, SentryDataCategory) {
    kSentryDataCategoryAll = 0,
    kSentryDataCategoryDefault = 1,
    kSentryDataCategoryError = 2,
    kSentryDataCategorySession = 3,
    kSentryDataCategoryTransaction = 4,
    kSentryDataCategoryAttachment = 5,
    kSentryDataCategoryUserFeedback = 6,
    kSentryDataCategoryProfile = 7,
    kSentryDataCategoryMetricBucket = 8,
    kSentryDataCategoryReplay = 9,
    kSentryDataCategoryProfileChunk = 10,
    kSentryDataCategorySpan = 11,
    kSentryDataCategoryUnknown = 12,
};
