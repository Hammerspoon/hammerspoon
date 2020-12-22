#import <Foundation/Foundation.h>

@class SentryEnvelope, SentryEvent, SentrySession, SentryUserFeedback;

NS_ASSUME_NONNULL_BEGIN

// TODO: align with unified SDK api
/**
 * Sends data to the Sentry server.
 */
NS_SWIFT_NAME(Transport)
@protocol SentryTransport <NSObject>

/**
 * Sends an event to sentry.
 * Triggerd when a event occurs. Thus the first try to upload an event.
 * CompletionHandler will be called if set.
 *
 * Failure to send will most likely keep this event on disk to batch upload it
 * on next app launch.
 *
 * @param event SentryEvent that should be sent
 */
- (void)sendEvent:(SentryEvent *)event NS_SWIFT_NAME(send(event:));

- (void)sendEvent:(SentryEvent *)event withSession:(SentrySession *)session;

- (void)sendUserFeedback:(SentryUserFeedback *)userFeedback NS_SWIFT_NAME(send(userFeedback:));

- (void)sendEnvelope:(SentryEnvelope *)envelope NS_SWIFT_NAME(send(envelope:));

@end

NS_ASSUME_NONNULL_END
