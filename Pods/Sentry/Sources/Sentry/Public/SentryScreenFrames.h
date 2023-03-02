#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

@interface SentryScreenFrames : NSObject
SENTRY_NO_INIT

- (instancetype)initWithTotal:(NSUInteger)total frozen:(NSUInteger)frozen slow:(NSUInteger)slow;

@property (nonatomic, assign, readonly) NSUInteger total;
@property (nonatomic, assign, readonly) NSUInteger frozen;
@property (nonatomic, assign, readonly) NSUInteger slow;

@end

#endif

NS_ASSUME_NONNULL_END
