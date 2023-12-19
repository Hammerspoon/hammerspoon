#import "SentryDefines.h"
#import "SentryScopeObserver.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * This class performs a fine-grained sync of the Scope to C memory, as when @c SentryCrash writes a
 * crash report, we can't call Objective-C methods; see @c SentryCrash.onCrash. For every change to
 * the Scope, this class serializes only the changed property to JSON and stores it in C memory.
 * When a crash happens, the @c SentryCrashReport picks up the JSON of all properties and adds it to
 * the crash report.
 * @discussion Previously, the SDK used @c SentryCrash.setUserInfo, which required the serialization
 * of the whole Scope on every modification of it. When having much data in the Scope this slowed
 * down the caller of the scope change. Therefore, we had to move the Scope sync to a background
 * thread. This has the downside of the scope not being 100% up to date when a crash happens and, of
 * course, lots of CPU overhead.
 */
@interface SentryCrashScopeObserver : NSObject <SentryScopeObserver>
SENTRY_NO_INIT

- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs;

@end

NS_ASSUME_NONNULL_END
