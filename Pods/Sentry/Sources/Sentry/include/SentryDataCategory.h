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
    kSentryDataCategoryUnknown = 8
};

static DEPRECATED_MSG_ATTRIBUTE(
    "Use one of the functions to convert between literals and enum cases in "
    "SentryDataCategoryMapper instead.") NSString *_Nonnull const SentryDataCategoryNames[]
    = {
          @"", // empty on purpose
          @"default",
          @"error",
          @"session",
          @"transaction",
          @"attachment",
          @"user_report",
          @"profile",
          @"unkown",
      };
