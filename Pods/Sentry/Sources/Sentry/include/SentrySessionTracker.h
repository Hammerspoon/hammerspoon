#import "SentryCurrentDateProvider.h"
#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryEvent, SentryOptions, SentryCurrentDateProvider;

/**
 * Tracks sessions for release health. For more info see:
 * https://docs.sentry.io/workflow/releases/health/#session
 */
NS_SWIFT_NAME(SessionTracker)
@interface SentrySessionTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options
            currentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider;
- (void)start;
- (void)stop;
@end
