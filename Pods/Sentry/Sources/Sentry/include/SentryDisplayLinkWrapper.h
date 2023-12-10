#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

/**
 * A wrapper around DisplayLink for testability.
 */
@interface SentryDisplayLinkWrapper : NSObject

@property (readonly, nonatomic) CFTimeInterval timestamp;

@property (readonly, nonatomic) CFTimeInterval targetTimestamp API_AVAILABLE(ios(10.0), tvos(10.0));

- (void)linkWithTarget:(id)target selector:(SEL)sel;

- (void)invalidate;

@end

#endif

NS_ASSUME_NONNULL_END
