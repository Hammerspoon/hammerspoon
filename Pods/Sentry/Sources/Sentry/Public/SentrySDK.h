#import <Foundation/Foundation.h>

#import "SentryDefines.h"

@class SentryHub, SentryOptions, SentryEvent, SentryBreadcrumb, SentryScope, SentryUser, SentryId,
    SentryUserFeedback;

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
 * Captures a manually created event and sends it to Sentry.
 *
 * @param event The event to send to Sentry.
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
+ (SentryId *)captureEvent:(SentryEvent *)event NS_SWIFT_NAME(capture(event:));

/**
 * Captures a manually created event and sends it to Sentry. Only the data in this scope object will
 * be added to the event. The global scope will be ignored.
 *
 * @param event The event to send to Sentry.
 * @param scope The scope containing event metadata.
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
+ (SentryId *)captureEvent:(SentryEvent *)event
                 withScope:(SentryScope *)scope NS_SWIFT_NAME(capture(event:scope:));

/**
 * Captures a manually created event and sends it to Sentry. Maintains the global scope but mutates
 * scope data for only this call.
 *
 * @param event The event to send to Sentry.
 * @param block The block mutating the scope only for this call.
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
+ (SentryId *)captureEvent:(SentryEvent *)event
            withScopeBlock:(void (^)(SentryScope *scope))block NS_SWIFT_NAME(capture(event:block:));

/**
 * Captures an error event and sends it to Sentry.
 *
 * @param error The error to send to Sentry.
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
+ (SentryId *)captureError:(NSError *)error NS_SWIFT_NAME(capture(error:));

/**
 * Captures an error event and sends it to Sentry. Only the data in this scope object will be added
 * to the event. The global scope will be ignored.
 *
 * @param error The error to send to Sentry.
 * @param scope The scope containing event metadata.
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
+ (SentryId *)captureError:(NSError *)error
                 withScope:(SentryScope *)scope NS_SWIFT_NAME(capture(error:scope:));

/**
 * Captures an error event and sends it to Sentry. Maintains the global scope but mutates scope data
 * for only this call.
 *
 * @param error The error to send to Sentry.
 * @param block The block mutating the scope only for this call.
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
+ (SentryId *)captureError:(NSError *)error
            withScopeBlock:(void (^)(SentryScope *scope))block NS_SWIFT_NAME(capture(error:block:));

/**
 * Captures an exception event and sends it to Sentry.
 *
 * @param exception The exception to send to Sentry.
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
+ (SentryId *)captureException:(NSException *)exception NS_SWIFT_NAME(capture(exception:));

/**
 * Captures an exception event and sends it to Sentry. Only the data in this scope object will be
 * added to the event. The global scope will be ignored.
 *
 * @param exception The exception to send to Sentry.
 * @param scope The scope containing event metadata.
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
+ (SentryId *)captureException:(NSException *)exception
                     withScope:(SentryScope *)scope NS_SWIFT_NAME(capture(exception:scope:));

/**
 * Captures an exception event and sends it to Sentry. Maintains the global scope but mutates scope
 * data for only this call.
 *
 * @param exception The exception to send to Sentry.
 * @param block The block mutating the scope only for this call.
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
+ (SentryId *)captureException:(NSException *)exception
                withScopeBlock:(void (^)(SentryScope *scope))block
    NS_SWIFT_NAME(capture(exception:block:));

/**
 * Captures a message event and sends it to Sentry.
 *
 * @param message The message to send to Sentry.
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
+ (SentryId *)captureMessage:(NSString *)message NS_SWIFT_NAME(capture(message:));

/**
 * Captures a message event and sends it to Sentry. Only the data in this scope object will be added
 * to the event. The global scope will be ignored.
 *
 * @param message The message to send to Sentry.
 * @param scope The scope containing event metadata.
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
+ (SentryId *)captureMessage:(NSString *)message
                   withScope:(SentryScope *)scope NS_SWIFT_NAME(capture(message:scope:));

/**
 * Captures a message event and sends it to Sentry. Maintains the global scope but mutates scope
 * data for only this call.
 *
 * @param message The message to send to Sentry.
 * @param block The block mutating the scope only for this call.
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
+ (SentryId *)captureMessage:(NSString *)message
              withScopeBlock:(void (^)(SentryScope *scope))block
    NS_SWIFT_NAME(capture(message:block:));

/**
 * Captures a manually created user feedback and sends it to Sentry.
 *
 * @param userFeedback The user feedback to send to Sentry.
 */
+ (void)captureUserFeedback:(SentryUserFeedback *)userFeedback
    NS_SWIFT_NAME(capture(userFeedback:));

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
 * Checks if the last program execution terminated with a crash.
 */
@property (nonatomic, class, readonly) BOOL crashedLastRun;

/**
 * Set global user -> thus will be sent with every event
 */
+ (void)setUser:(SentryUser *_Nullable)user;

@end

NS_ASSUME_NONNULL_END
