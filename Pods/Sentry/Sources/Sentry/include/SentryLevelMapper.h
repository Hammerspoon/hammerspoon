#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Maps a string to a SentryLevel. If the passed string doesn't match any level this defaults to
 * the 'error' level. See https://develop.sentry.dev/sdk/event-payloads/#optional-attributes
 */
SentryLevel sentryLevelForString(NSString *string);

NSString *nameForSentryLevel(SentryLevel level);

NS_ASSUME_NONNULL_END
