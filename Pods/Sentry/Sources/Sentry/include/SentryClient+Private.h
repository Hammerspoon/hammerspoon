#import "SentryClient.h"
#import <Foundation/Foundation.h>

@class SentryId;

NS_ASSUME_NONNULL_BEGIN

@interface SentryClient (Private)

- (SentryFileManager *)fileManager;

- (SentryId *)captureError:(NSError *)error
               withSession:(SentrySession *)session
                 withScope:(SentryScope *)scope;

- (SentryId *)captureException:(NSException *)exception
                   withSession:(SentrySession *)session
                     withScope:(SentryScope *)scope;

- (SentryId *)captureCrashEvent:(SentryEvent *)event withScope:(SentryScope *)scope;

- (SentryId *)captureCrashEvent:(SentryEvent *)event
                    withSession:(SentrySession *)session
                      withScope:(SentryScope *)scope;

/**
 * Needed by hybrid SDKs as react-native to synchronously store an envelope to disk.
 */
- (void)storeEnvelope:(SentryEnvelope *)envelope;

@end

NS_ASSUME_NONNULL_END
