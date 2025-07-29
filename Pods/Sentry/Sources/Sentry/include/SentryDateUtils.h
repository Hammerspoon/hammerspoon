#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN NSDateFormatter *sentryGetIso8601FormatterWithMillisecondPrecision(void);

SENTRY_EXTERN NSDate *_Nullable sentry_fromIso8601String(NSString *string);

SENTRY_EXTERN NSString *sentry_toIso8601String(NSDate *date);

NS_ASSUME_NONNULL_END
