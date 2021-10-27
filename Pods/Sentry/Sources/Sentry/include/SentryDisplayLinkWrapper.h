#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

/**
 * A wrapper around DisplayLink for testability.
 */
@interface SentryDisplayLinkWrapper : NSObject

@property (readonly, nonatomic) CFTimeInterval timestamp;

- (void)linkWithTarget:(id)target selector:(SEL)sel;

- (void)invalidate;

@end

#endif

NS_ASSUME_NONNULL_END
