#import <Foundation/Foundation.h>

#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SentryError) {
    kSentryErrorUnknownError = -1,
    kSentryErrorInvalidDsnError = 100,
    kSentryErrorSentryCrashNotInstalledError = 101,
    kSentryErrorInvalidCrashReportError = 102,
    kSentryErrorCompressionError = 103,
    kSentryErrorJsonConversionError = 104,
    kSentryErrorCouldNotFindDirectory = 105,
    kSentryErrorRequestError = 106,
    kSentryErrorEventNotSent = 107,
};

SENTRY_EXTERN NSError *_Nullable NSErrorFromSentryError(SentryError error, NSString *description);

SENTRY_EXTERN NSString *const SentryErrorDomain;

NS_ASSUME_NONNULL_END
