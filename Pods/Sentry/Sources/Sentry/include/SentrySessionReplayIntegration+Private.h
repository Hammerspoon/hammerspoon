#import "SentryBaseIntegration.h"
#import "SentrySessionReplayIntegration.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

@class SentrySessionReplay;
@class SentryViewPhotographer;

@interface SentrySessionReplayIntegration ()

@property (nonatomic, strong) SentrySessionReplay *sessionReplay;

@property (nonatomic, strong) SentryViewPhotographer *viewPhotographer;

- (void)setReplayTags:(NSDictionary<NSString *, id> *)tags;

@end

#endif
