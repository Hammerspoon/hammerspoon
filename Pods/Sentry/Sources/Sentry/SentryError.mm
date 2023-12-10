#import "SentryError.h"
#import "SentryMachLogging.hpp"

NS_ASSUME_NONNULL_BEGIN

NSString *const SentryErrorDomain = @"SentryErrorDomain";

NSError *_Nullable _SentryError(SentryError error, NSDictionary *userInfo)
{
    return [NSError errorWithDomain:SentryErrorDomain code:error userInfo:userInfo];
}

NSError *_Nullable NSErrorFromSentryErrorWithUnderlyingError(
    SentryError error, NSString *description, NSError *underlyingError)
{
    return _SentryError(error,
        @ { NSLocalizedDescriptionKey : description, NSUnderlyingErrorKey : underlyingError });
}

NSError *_Nullable NSErrorFromSentryErrorWithException(
    SentryError error, NSString *description, NSException *exception)
{
    return _SentryError(error, @ {
        NSLocalizedDescriptionKey :
            [NSString stringWithFormat:@"%@ (%@)", description, exception.reason],
    });
}

SENTRY_EXTERN NSError *_Nullable NSErrorFromSentryErrorWithKernelError(
    SentryError error, NSString *description, kern_return_t kernelErrorCode)
{
    return _SentryError(error, @ {
        NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@ (%s)", description,
                                              sentry::kernelReturnCodeDescription(kernelErrorCode)],
    });
}

NSError *_Nullable NSErrorFromSentryError(SentryError error, NSString *description)
{
    return _SentryError(error, @ { NSLocalizedDescriptionKey : description });
}

NS_ASSUME_NONNULL_END
