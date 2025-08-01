#import <Foundation/Foundation.h>

// Clang warns if a double quoted include is used instead of angle brackets in a public header
// These 3 import variations are how public headers can be imported with angle brackets
// for Sentry, SentryWithoutUIKit, and SPM
#if __has_include(<Sentry/Sentry.h>)
#    define SENTRY_HEADER(file) <Sentry/file.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    define SENTRY_HEADER(file) <SentryWithoutUIKit/file.h>
#else
#    define SENTRY_HEADER(file) <file.h>
#endif

#ifdef __cplusplus
#    define SENTRY_EXTERN extern "C" __attribute__((visibility("default")))
#else
#    define SENTRY_EXTERN extern __attribute__((visibility("default")))
#endif

#ifndef TARGET_OS_VISION
#    define TARGET_OS_VISION 0
#endif

// SENTRY_UIKIT_AVAILABLE basically means: are we on a platform where we can link UIKit?
#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
#    define SENTRY_UIKIT_AVAILABLE 1
#else
#    define SENTRY_UIKIT_AVAILABLE 0
#endif

// SENTRY_HAS_UIKIT means we're on a platform that can link UIKit and we're building a configuration
// that will allow it to be autolinked. SENTRY_NO_UIKIT is set in GCC_PREPROCESSOR_DEFINITIONS
// for configurations that we will not allow to link UIKit by setting CLANG_MODULES_AUTOLINK to NO.
#if SENTRY_UIKIT_AVAILABLE && !SENTRY_NO_UIKIT
#    define SENTRY_HAS_UIKIT 1
#else
#    define SENTRY_HAS_UIKIT 0
#endif

#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
#    define SENTRY_TARGET_MACOS 1
#else
#    define SENTRY_TARGET_MACOS 0
#endif

#if (TARGET_OS_OSX || TARGET_OS_MACCATALYST) && !SENTRY_NO_UIKIT
#    define SENTRY_TARGET_MACOS_HAS_UI 1
#else
#    define SENTRY_TARGET_MACOS_HAS_UI 0
#endif

#if TARGET_OS_IOS || SENTRY_TARGET_MACOS
#    define SENTRY_HAS_METRIC_KIT 1
#else
#    define SENTRY_HAS_METRIC_KIT 0
#endif

#if SENTRY_HAS_UIKIT && !TARGET_OS_VISION
#    define SENTRY_TARGET_REPLAY_SUPPORTED 1
#else
#    define SENTRY_TARGET_REPLAY_SUPPORTED 0
#endif

#define SENTRY_NO_INIT                                                                             \
    -(instancetype)init NS_UNAVAILABLE;                                                            \
    +(instancetype) new NS_UNAVAILABLE;

#if !TARGET_OS_WATCH && !(TARGET_OS_VISION && SENTRY_NO_UIKIT == 1)
#    define SENTRY_HAS_REACHABILITY 1
#else
#    define SENTRY_HAS_REACHABILITY 0
#endif

@class SentryBreadcrumb;
@class SentryEvent;
@class SentrySamplingContext;
@class SentryUserFeedbackConfiguration;
@protocol SentrySpan;

/**
 * Block used for returning after a request finished
 */
typedef void (^SentryRequestFinished)(NSError *_Nullable error);

/**
 * Block used for request operation finished, @c shouldDiscardEvent is @c YES if event
 * should be deleted regardless if an error occurred or not
 */
typedef void (^SentryRequestOperationFinished)(
    NSHTTPURLResponse *_Nullable response, NSError *_Nullable error);
/**
 * Block can be used to mutate a breadcrumb before it's added to the scope.
 * To avoid adding the breadcrumb altogether, return @c nil instead.
 */
typedef SentryBreadcrumb *_Nullable (^SentryBeforeBreadcrumbCallback)(
    SentryBreadcrumb *_Nonnull breadcrumb);

/**
 * Block can be used to mutate event before its send.
 * To avoid sending the event altogether, return nil instead.
 */
typedef SentryEvent *_Nullable (^SentryBeforeSendEventCallback)(SentryEvent *_Nonnull event);

/**
 * Use this block to drop or modify a span before the SDK sends it to Sentry. Return @c nil to drop
 * the span.
 */
typedef id<SentrySpan> _Nullable (^SentryBeforeSendSpanCallback)(id<SentrySpan> _Nonnull span);

/**
 * Block can be used to decide if the SDK should capture a screenshot or not. Return @c true if the
 * SDK should capture a screenshot, return @c false if not. This callback doesn't work for crashes.
 */
typedef BOOL (^SentryBeforeCaptureScreenshotCallback)(SentryEvent *_Nonnull event);

/**
 * Block can be used to decide if the SDK should capture a view hierarchy or not. Return @c true if
 * the SDK should capture a view hierarchy, return @c false if not. This callback doesn't work for
 * crashes.
 */
typedef BOOL (^SentryBeforeCaptureViewHierarchyCallback)(SentryEvent *_Nonnull event);

/**
 * A callback to be notified when the last program execution terminated with a crash.
 */
typedef void (^SentryOnCrashedLastRunCallback)(SentryEvent *_Nonnull event);

/**
 * Block can be used to determine if an event should be queued and stored
 * locally. It will be tried to send again after next successful send. Note that
 * this will only be called once the event is created and send manually. Once it
 * has been queued once it will be discarded if it fails again.
 */
typedef BOOL (^SentryShouldQueueEvent)(
    NSHTTPURLResponse *_Nullable response, NSError *_Nullable error);

/**
 * Function pointer for a sampler callback.
 * @param samplingContext context of the sampling.
 * @return A sample rate that is >=  @c 0.0 and \<= @c 1.0 or @c nil if no sampling decision has
 * been taken. When returning a value out of range the SDK uses the default of @c 0.
 */
typedef NSNumber *_Nullable (^SentryTracesSamplerCallback)(
    SentrySamplingContext *_Nonnull samplingContext);

/**
 * Function pointer for span manipulation.
 * @param span The span to be used.
 */
typedef void (^SentrySpanCallback)(id<SentrySpan> _Nullable span DEPRECATED_MSG_ATTRIBUTE(
    "See `SentryScope.useSpan` for reasoning of deprecation."));

#if !SDK_V9
/**
 * Log level.
 */
typedef NS_ENUM(NSInteger, SentryLogLevel) {
    kSentryLogLevelNone = 1,
    kSentryLogLevelError,
    kSentryLogLevelDebug,
    kSentryLogLevelVerbose
};
#endif // !SDK_V9

/**
 * Sentry level.
 */
typedef NS_ENUM(NSUInteger,
    SentryLevel); // This is a forward declaration, the actual enum is implemented in Swift.

/**
 * Static internal helper to convert enum to string.
 */
static DEPRECATED_MSG_ATTRIBUTE(
    "Use nameForSentryLevel() instead.") NSString *_Nonnull const SentryLevelNames[]
    = {
          @"none",
          @"debug",
          @"info",
          @"warning",
          @"error",
          @"fatal",
      };

static NSUInteger const defaultMaxBreadcrumbs = 100;

static NSString *_Nonnull const kSentryTrueString = @"true";
static NSString *_Nonnull const kSentryFalseString = @"false";

/**
 * Transaction name source.
 */
typedef NS_ENUM(NSInteger, SentryTransactionNameSource); // This is a forward declaration, the
                                                         // actual enum is implemented in Swift.

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

/**
 * Block used to configure the user feedback widget, form, behaviors and submission data.
 */
API_AVAILABLE(ios(13.0))
typedef void (^SentryUserFeedbackConfigurationBlock)(
    SentryUserFeedbackConfiguration *_Nonnull configuration);

#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
