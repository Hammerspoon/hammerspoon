#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@protocol SentryUIEventTrackerMode <NSObject>

- (void)handleUIEvent:(NSString *)action
                  operation:(NSString *)operation
    accessibilityIdentifier:(NSString *)accessibilityIdentifier;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
