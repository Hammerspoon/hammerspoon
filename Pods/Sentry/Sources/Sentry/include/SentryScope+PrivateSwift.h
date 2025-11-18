#import "SentryScope.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const SENTRY_CONTEXT_OS_KEY = @"os";
static NSString *const SENTRY_CONTEXT_DEVICE_KEY = @"device";

// Added to only expose a limited sub-set of internal API needed in the Swift layer.
@interface SentryScope ()

// This is a workaround to make the traceId available in the Swift layer.
// Can't expose the SentryId directly for some reason.
@property (nonatomic, readonly) NSString *propagationContextTraceIdString;

/**
 * Set global user -> thus will be sent with every event
 */
@property (atomic, strong) SentryUser *_Nullable userObject;

- (NSDictionary<NSString *, id> *_Nullable)getContextForKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
