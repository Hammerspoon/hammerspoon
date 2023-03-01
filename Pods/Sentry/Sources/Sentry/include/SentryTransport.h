#import "SentryDataCategory.h"
#import "SentryDiscardReason.h"
#import <Foundation/Foundation.h>

@class SentryEnvelope;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Transport)
@protocol SentryTransport <NSObject>

- (void)sendEnvelope:(SentryEnvelope *)envelope NS_SWIFT_NAME(send(envelope:));

- (void)recordLostEvent:(SentryDataCategory)category reason:(SentryDiscardReason)reason;

- (BOOL)flush:(NSTimeInterval)timeout;

@end

NS_ASSUME_NONNULL_END
