#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentryTransport.h"

@class SentryOptions, SentrySession, SentryEvent, SentryScope, SentryThread, SentryEnvelope,
    SentryFileManager;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Client)
@interface SentryClient : NSObject
SENTRY_NO_INIT

@property (nonatomic, strong) SentryOptions *options;

/**
 * Initializes a SentryClient. Pass in an dictionary of options.
 *
 * @param options Options dictionary
 * @return SentryClient
 */
- (_Nullable instancetype)initWithOptions:(SentryOptions *)options;

/**
 * Captures an SentryEvent
 */
- (NSString *_Nullable)captureEvent:(SentryEvent *)event
                          withScope:(SentryScope *_Nullable)scope
    NS_SWIFT_NAME(capture(event:scope:));

/**
 * Captures a NSError
 */
- (NSString *_Nullable)captureError:(NSError *)error
                          withScope:(SentryScope *_Nullable)scope
    NS_SWIFT_NAME(capture(error:scope:));

/**
 * Captures a NSException
 */
- (NSString *_Nullable)captureException:(NSException *)exception
                              withScope:(SentryScope *_Nullable)scope
    NS_SWIFT_NAME(capture(exception:scope:));

/**
 * Captures a Message
 */
- (NSString *_Nullable)captureMessage:(NSString *)message
                            withScope:(SentryScope *_Nullable)scope
    NS_SWIFT_NAME(capture(message:scope:));

- (void)captureSession:(SentrySession *)session NS_SWIFT_NAME(capture(session:));

- (NSString *_Nullable)captureEnvelope:(SentryEnvelope *)envelope NS_SWIFT_NAME(capture(envelope:));

- (SentryFileManager *)fileManager;

@end

NS_ASSUME_NONNULL_END
