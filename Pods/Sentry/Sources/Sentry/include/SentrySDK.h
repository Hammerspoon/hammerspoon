#import <Foundation/Foundation.h>

#import "SentryBreadcrumb.h"
#import "SentryDefines.h"
#import "SentryEvent.h"
#import "SentryHub.h"
#import "SentryOptions.h"

NS_ASSUME_NONNULL_BEGIN

// NS_SWIFT_NAME(SDK)
/**
 "static api" for easy access to most common sentry sdk features

 try `SentryHub` for advanced features
 */
@interface SentrySDK : NSObject
SENTRY_NO_INIT

/**
 * Returns current hub
 */
+ (SentryHub *)currentHub;

/**
 * This forces a crash, useful to test the SentryCrash integration
 */
+ (void)crash;

/**
 * Sets current hub
 */
+ (void)setCurrentHub:(SentryHub *)hub;

/**
 * Use [SentrySDK startWithOptionsObject] / SentrySDK.start(:) instead
 * @deprecated
 */
+ (instancetype)initWithOptionsObject:(SentryOptions *)options NS_SWIFT_NAME(init(options:))
                                          __attribute((deprecated(("Use startWithOptionsObject"))));

/**
 * Use [SentrySDK startWithOptions] / SentrySDK.start(:) instead
 * @deprecated
 */
+ (instancetype)initWithOptions:(NSDictionary<NSString *, id> *)optionsDict
    NS_SWIFT_NAME(init(options:))__attribute((deprecated(("Use startWithOptions"))));

/**
 * Inits and configures Sentry (SentryHub, SentryClient) and sets up all integrations.
 */
+ (void)startWithOptions:(NSDictionary<NSString *, id> *)optionsDict NS_SWIFT_NAME(start(options:));

/**
 * Inits and configures Sentry (SentryHub, SentryClient) and sets up all integrations.
 */
+ (void)startWithOptionsObject:(SentryOptions *)options NS_SWIFT_NAME(start(options:));

/**
 * Inits and configures Sentry (SentryHub, SentryClient) and sets up all integrations. Make sure to
 * set a valid DSN otherwise.
 */
+ (void)startWithConfigureOptions:(void (^)(SentryOptions *options))configureOptions
    NS_SWIFT_NAME(start(configureOptions:));

/**
 * captures an event aka. sends an event to sentry
 *
 * uses default `SentryHub`
 *
 * USAGE: Create a `SentryEvent`, fill it up with data, and send it with this
 * method.
 */
+ (NSString *_Nullable)captureEvent:(SentryEvent *)event NS_SWIFT_NAME(capture(event:));
+ (NSString *_Nullable)captureEvent:(SentryEvent *)event
                          withScope:(SentryScope *_Nullable)scope
    NS_SWIFT_NAME(capture(event:scope:));
+ (NSString *_Nullable)captureEvent:(SentryEvent *)event
                     withScopeBlock:(void (^)(SentryScope *scope))block
    NS_SWIFT_NAME(capture(event:block:));

/**
 captures an error aka. sends an NSError to sentry.

 uses default `SentryHub`
 */
+ (NSString *_Nullable)captureError:(NSError *)error NS_SWIFT_NAME(capture(error:));
+ (NSString *_Nullable)captureError:(NSError *)error
                          withScope:(SentryScope *_Nullable)scope
    NS_SWIFT_NAME(capture(error:scope:));
+ (NSString *_Nullable)captureError:(NSError *)error
                     withScopeBlock:(void (^)(SentryScope *scope))block
    NS_SWIFT_NAME(capture(error:block:));

/**
 captures an exception aka. sends an NSException to sentry.

 uses default `SentryHub`
 */
+ (NSString *_Nullable)captureException:(NSException *)exception NS_SWIFT_NAME(capture(exception:));
+ (NSString *_Nullable)captureException:(NSException *)exception
                              withScope:(SentryScope *_Nullable)scope
    NS_SWIFT_NAME(capture(exception:scope:));
+ (NSString *_Nullable)captureException:(NSException *)exception
                         withScopeBlock:(void (^)(SentryScope *scope))block
    NS_SWIFT_NAME(capture(exception:block:));

/**
 captures a message aka. sends a string to sentry.

 uses default `SentryHub`
 */
+ (NSString *_Nullable)captureMessage:(NSString *)message NS_SWIFT_NAME(capture(message:));
+ (NSString *_Nullable)captureMessage:(NSString *)message
                            withScope:(SentryScope *_Nullable)scope
    NS_SWIFT_NAME(capture(message:scope:));
+ (NSString *_Nullable)captureMessage:(NSString *)message
                       withScopeBlock:(void (^)(SentryScope *scope))block
    NS_SWIFT_NAME(capture(message:block:));

/**
 * Adds a SentryBreadcrumb to the current Scope on the `currentHub`.
 * If the total number of breadcrumbs exceeds the `max_breadcrumbs` setting, the
 * oldest breadcrumb is removed.
 */
+ (void)addBreadcrumb:(SentryBreadcrumb *)crumb NS_SWIFT_NAME(addBreadcrumb(crumb:));

//- `configure_scope(callback)`: Calls a callback with a scope object that can
// be reconfigured. This is used to attach contextual data for future events in
// the same scope.
+ (void)configureScope:(void (^)(SentryScope *scope))callback;

/**
 * Set logLevel for the current client default kSentryLogLevelError
 */
@property (nonatomic, class) SentryLogLevel logLevel;

/**
 * Set global user -> thus will be sent with every event
 */
+ (void)setUser:(SentryUser *_Nullable)user;

@end

NS_ASSUME_NONNULL_END
