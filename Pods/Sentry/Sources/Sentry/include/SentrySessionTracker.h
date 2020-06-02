#import <Foundation/Foundation.h>

#import "SentryEvent.h"
#import "SentryOptions.h"

@interface SentrySessionTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options;
- (void)start;
@end
