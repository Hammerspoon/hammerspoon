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
    kSentryErrorFileIO = 108,
    kSentryErrorKernel = 109,
};

SENTRY_EXTERN NSError *_Nullable NSErrorFromSentryError(SentryError error, NSString *description);
SENTRY_EXTERN NSError *_Nullable NSErrorFromSentryErrorWithUnderlyingError(
    SentryError error, NSString *description, NSError *underlyingError);
SENTRY_EXTERN NSError *_Nullable NSErrorFromSentryErrorWithException(
    SentryError error, NSString *description, NSException *exception);
SENTRY_EXTERN NSError *_Nullable NSErrorFromSentryErrorWithKernelError(
    SentryError error, NSString *description, kern_return_t kernelErrorCode);

SENTRY_EXTERN NSString *const SentryErrorDomain;

NS_ASSUME_NONNULL_END
