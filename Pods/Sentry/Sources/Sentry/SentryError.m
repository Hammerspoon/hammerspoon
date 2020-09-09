#import "SentryError.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const SentryErrorDomain = @"SentryErrorDomain";

NSError *_Nullable NSErrorFromSentryError(SentryError error, NSString *description)
{
    NSMutableDictionary *userInfo = [NSMutableDictionary new];
    [userInfo setValue:description forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:SentryErrorDomain code:error userInfo:userInfo];
}

NS_ASSUME_NONNULL_END
