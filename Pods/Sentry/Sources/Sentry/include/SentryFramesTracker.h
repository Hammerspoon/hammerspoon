#import "SentryDefines.h"

@class SentryOptions, SentryDisplayLinkWrapper, SentryScreenFrames;

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

/**
 * Tracks total, frozen and slow frames for iOS, tvOS, and Mac Catalyst.
 */
@interface SentryFramesTracker : NSObject
SENTRY_NO_INIT

+ (instancetype)sharedInstance;

@property (nonatomic, assign, readonly) SentryScreenFrames *currentFrames;
@property (nonatomic, assign, readonly) BOOL isRunning;

- (void)start;
- (void)stop;

@end

#endif

NS_ASSUME_NONNULL_END
