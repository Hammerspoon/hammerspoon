#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Transaction)
@interface SentryTransaction : SentryEvent
SENTRY_NO_INIT

- (instancetype)initWithTrace:(id<SentrySpan>)trace childs:(NSArray<id<SentrySpan>> *)childs;

@end

NS_ASSUME_NONNULL_END
