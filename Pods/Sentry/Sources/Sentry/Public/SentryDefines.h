#import <Foundation/Foundation.h>

#ifdef __cplusplus
#    define SENTRY_EXTERN extern "C" __attribute__((visibility("default")))
#else
#    define SENTRY_EXTERN extern __attribute__((visibility("default")))
#endif

#if TARGET_OS_IOS || TARGET_OS_TV
#    define SENTRY_HAS_UIDEVICE 1
#else
#    define SENTRY_HAS_UIDEVICE 0
#endif

#if SENTRY_HAS_UIDEVICE
#    define SENTRY_HAS_UIKIT 1
#else
#    define SENTRY_HAS_UIKIT 0
#endif

#define SENTRY_NO_INIT                                                                             \
    -(instancetype)init NS_UNAVAILABLE;                                                            \
    +(instancetype) new NS_UNAVAILABLE;

@class SentryEvent, SentryBreadcrumb;

/**
 * Block used for returning after a request finished
 */
typedef void (^SentryRequestFinished)(NSError *_Nullable error);

/**
 * Block used for request operation finished, shouldDiscardEvent is YES if event
 * should be deleted regardless if an error ocured or not
 */
typedef void (^SentryRequestOperationFinished)(
    NSHTTPURLResponse *_Nullable response, NSError *_Nullable error);
/**
 * Block can be used to mutate a breadcrumb before it's added to the scope.
 * To avoid adding the breadcrumb altogether, return nil instead.
 */
typedef SentryBreadcrumb *_Nullable (^SentryBeforeBreadcrumbCallback)(
    SentryBreadcrumb *_Nonnull breadcrumb);

/**
 * Block can be used to mutate event before its send.
 * To avoid sending the event altogether, return nil instead.
 */
typedef SentryEvent *_Nullable (^SentryBeforeSendEventCallback)(SentryEvent *_Nonnull event);

/**
 * Block can be used to determine if an event should be queued and stored
 * locally. It will be tried to send again after next successful send. Note that
 * this will only be called once the event is created and send manully. Once it
 * has been queued once it will be discarded if it fails again.
 */
typedef BOOL (^SentryShouldQueueEvent)(
    NSHTTPURLResponse *_Nullable response, NSError *_Nullable error);
/**
 * Loglevel
 */
typedef NS_ENUM(NSInteger, SentryLogLevel) {
    kSentryLogLevelNone = 1,
    kSentryLogLevelError,
    kSentryLogLevelDebug,
    kSentryLogLevelVerbose
};

/**
 * Sentry level
 */
typedef NS_ENUM(NSUInteger, SentryLevel) {
    // Defaults to None which doesn't get serialized
    kSentryLevelNone = 0,
    // Goes from Debug to Fatal so possible to: (level > Info) { .. }
    kSentryLevelDebug = 1,
    kSentryLevelInfo = 2,
    kSentryLevelWarning = 3,
    kSentryLevelError = 4,
    kSentryLevelFatal = 5,
};

/**
 * Static internal helper to convert enum to string
 */
static NSString *_Nonnull const SentryLevelNames[] = {
    @"none",
    @"debug",
    @"info",
    @"warning",
    @"error",
    @"fatal",
};

static NSUInteger const defaultMaxBreadcrumbs = 100;
