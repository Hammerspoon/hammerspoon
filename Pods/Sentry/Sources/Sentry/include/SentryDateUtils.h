#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN NSDate *sentry_fromIso8601String(NSString *string);

SENTRY_EXTERN NSString *sentry_toIso8601String(NSDate *date);

NS_ASSUME_NONNULL_END
