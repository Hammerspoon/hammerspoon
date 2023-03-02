#import <Foundation/Foundation.h>

#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryLevelMapper : NSObject

/**
 * Maps a string to a SentryLevel. If the passed string doesn't match any level this defaults to
 * the 'error' level. See https://develop.sentry.dev/sdk/event-payloads/#optional-attributes
 */
+ (SentryLevel)levelWithString:(NSString *)string;

@end

NS_ASSUME_NONNULL_END
