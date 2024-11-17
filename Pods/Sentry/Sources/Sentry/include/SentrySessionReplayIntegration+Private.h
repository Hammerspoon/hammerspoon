#import "SentryBaseIntegration.h"
#import "SentrySessionReplayIntegration.h"
#import "SentrySwift.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

@class SentrySessionReplay;

@interface
SentrySessionReplayIntegration () <SentryIntegrationProtocol, SentrySessionListener,
    SentrySessionReplayDelegate>

@property (nonatomic, strong) SentrySessionReplay *sessionReplay;

@end

#endif
