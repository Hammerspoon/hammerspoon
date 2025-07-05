#import "SentryBaseIntegration.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Automatically tracks session start and end.
 */
@interface SentryAutoSessionTrackingIntegration : SentryBaseIntegration

- (void)stop;

@end

NS_ASSUME_NONNULL_END
