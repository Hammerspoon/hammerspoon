#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentryRateLimits.h"
#import "SentryRequestManager.h"
#import "SentryTransport.h"

@class SentryEnvelopeRateLimit, SentryOptions, SentryEvent;

NS_ASSUME_NONNULL_BEGIN

@interface SentryHttpTransport : NSObject <SentryTransport>
SENTRY_NO_INIT

- (id)initWithOptions:(SentryOptions *)options
          sentryFileManager:(SentryFileManager *)sentryFileManager
       sentryRequestManager:(id<SentryRequestManager>)sentryRequestManager
           sentryRateLimits:(id<SentryRateLimits>)sentryRateLimits
    sentryEnvelopeRateLimit:(SentryEnvelopeRateLimit *)envelopeRateLimit;

/**
 * This is triggered after the first upload attempt of an event. Checks if event
 * should stay on disk to be uploaded when `sendCachedEventsAndEnvelopes` is
 * triggerd.
 *
 * Within `sendCachedEventsAndEnvelopes` this function isn't triggerd.
 *
 * @return BOOL YES = store and try again later, NO = delete
 */
@property (nonatomic, copy) SentryShouldQueueEvent _Nullable shouldQueueEvent;

/**
 * Contains the last successfully sent event
 */
@property (nonatomic, strong) SentryEvent *_Nullable lastEvent;

@end

NS_ASSUME_NONNULL_END
