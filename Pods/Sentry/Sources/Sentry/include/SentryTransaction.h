#import "SentryEvent.h"
#import "SentrySpanProtocol.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Transaction)
@interface SentryTransaction : SentryEvent
SENTRY_NO_INIT

- (instancetype)initWithTrace:(id<SentrySpan>)trace children:(NSArray<id<SentrySpan>> *)children;

@end

NS_ASSUME_NONNULL_END
