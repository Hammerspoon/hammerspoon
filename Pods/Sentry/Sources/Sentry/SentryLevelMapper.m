#import "SentryLevelMapper.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryLevelMapper

+ (SentryLevel)levelWithString:(NSString *)string
{
    if ([string isEqualToString:SentryLevelNames[kSentryLevelNone]]) {
        return kSentryLevelNone;
    }
    if ([string isEqualToString:SentryLevelNames[kSentryLevelDebug]]) {
        return kSentryLevelDebug;
    }
    if ([string isEqualToString:SentryLevelNames[kSentryLevelInfo]]) {
        return kSentryLevelInfo;
    }
    if ([string isEqualToString:SentryLevelNames[kSentryLevelWarning]]) {
        return kSentryLevelWarning;
    }
    if ([string isEqualToString:SentryLevelNames[kSentryLevelError]]) {
        return kSentryLevelError;
    }
    if ([string isEqualToString:SentryLevelNames[kSentryLevelFatal]]) {
        return kSentryLevelFatal;
    }

    // Default is error, see https://develop.sentry.dev/sdk/event-payloads/#optional-attributes
    return kSentryLevelError;
}

@end

NS_ASSUME_NONNULL_END
