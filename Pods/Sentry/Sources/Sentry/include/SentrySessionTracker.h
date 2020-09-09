#import <Foundation/Foundation.h>

#import "SentryCurrentDateProvider.h"
#import "SentryEvent.h"
#import "SentryOptions.h"

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
