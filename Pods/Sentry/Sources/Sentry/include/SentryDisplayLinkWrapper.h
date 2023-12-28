#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

/**
 * A wrapper around DisplayLink for testability.
 */
@interface SentryDisplayLinkWrapper : NSObject

@property (readonly, nonatomic) CFTimeInterval timestamp;

@property (readonly, nonatomic) CFTimeInterval targetTimestamp API_AVAILABLE(ios(10.0), tvos(10.0));

- (void)linkWithTarget:(id)target selector:(SEL)sel;

- (void)invalidate;

@end

NS_ASSUME_NONNULL_END

#endif //
