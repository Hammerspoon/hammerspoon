#import "SentryDefines.h"
#import "SentryObjCRuntimeWrapper.h"

/**
 * A wrapper around the objc runtime functions for testability.
 */
@interface SentryDefaultObjCRuntimeWrapper : NSObject <SentryObjCRuntimeWrapper>
SENTRY_NO_INIT

+ (instancetype)sharedInstance;

@end
