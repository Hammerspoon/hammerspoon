#import "SentryDefines.h"

@class SentryOptions, SentryOutOfMemoryLogic, SentryDispatchQueueWrapper;

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryOutOfMemoryExceptionType = @"OutOfMemory";
static NSString *const SentryOutOfMemoryExceptionValue
    = @"The OS most likely terminated your app because it overused RAM.";
static NSString *const SentryOutOfMemoryMechanismType = @"out_of_memory";

/**
 * Detect OOMs based on heuristics described in a blog post:
 * https://engineering.fb.com/2015/08/24/ios/reducing-fooms-in-the-facebook-ios-app/ If a OOM is
 * detected, the SDK sends it as crash event. Only works for iOS, tvOS and macCatalyst.
 */
@interface SentryOutOfMemoryTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options
               outOfMemoryLogic:(SentryOutOfMemoryLogic *)outOfMemoryLogic
           dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
