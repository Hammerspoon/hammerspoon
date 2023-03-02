#import "SentryLevelMapper.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const kSentryLevelNameNone = @"none";
NSString *const kSentryLevelNameDebug = @"debug";
NSString *const kSentryLevelNameInfo = @"info";
NSString *const kSentryLevelNameWarning = @"warning";
NSString *const kSentryLevelNameError = @"error";
NSString *const kSentryLevelNameFatal = @"fatal";

SentryLevel
sentryLevelForString(NSString *string)
{
    if ([string isEqualToString:kSentryLevelNameNone]) {
        return kSentryLevelNone;
    }
    if ([string isEqualToString:kSentryLevelNameDebug]) {
        return kSentryLevelDebug;
    }
    if ([string isEqualToString:kSentryLevelNameInfo]) {
        return kSentryLevelInfo;
    }
    if ([string isEqualToString:kSentryLevelNameWarning]) {
        return kSentryLevelWarning;
    }
    if ([string isEqualToString:kSentryLevelNameError]) {
        return kSentryLevelError;
    }
    if ([string isEqualToString:kSentryLevelNameFatal]) {
        return kSentryLevelFatal;
    }

    // Default is error, see https://develop.sentry.dev/sdk/event-payloads/#optional-attributes
    return kSentryLevelError;
}

NSString *
nameForSentryLevel(SentryLevel level)
{
    switch (level) {
    case kSentryLevelNone:
        return kSentryLevelNameNone;
    case kSentryLevelDebug:
        return kSentryLevelNameDebug;
    case kSentryLevelInfo:
        return kSentryLevelNameInfo;
    case kSentryLevelWarning:
        return kSentryLevelNameWarning;
    case kSentryLevelError:
        return kSentryLevelNameError;
    case kSentryLevelFatal:
        return kSentryLevelNameFatal;
    }
}

NS_ASSUME_NONNULL_END
