#import "SentryDefines.h"
#import "SentryEvent.h"
#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

@interface
SentryEvent ()

/**
 * This indicates whether this event is a result of a crash.
 */
@property (nonatomic) BOOL isCrashEvent;

/**
 * This indicates whether this event represents an app hang.
 */
@property (nonatomic, readonly) BOOL isAppHangEvent;

/**
 * We're storing serialized breadcrumbs to disk in JSON, and when we're reading them back (in
 * the case of OOM), we end up with the serialized breadcrumbs again. Instead of turning those
 * dictionaries into proper SentryBreadcrumb instances which then need to be serialized again in
 * SentryEvent, we use this serializedBreadcrumbs property to set the pre-serialized
 * breadcrumbs. It saves a LOT of work - especially turning an NSDictionary into a SentryBreadcrumb
 * is silly when we're just going to do the opposite right after.
 */
@property (nonatomic, strong) NSArray *serializedBreadcrumbs;

#if SENTRY_TARGET_PROFILING_SUPPORTED
@property (nonatomic) uint64_t startSystemTime;
@property (nonatomic) uint64_t endSystemTime;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

#if SENTRY_HAS_METRIC_KIT
- (BOOL)isMetricKitEvent;
#endif // SENTRY_HAS_METRIC_KIT

@end
