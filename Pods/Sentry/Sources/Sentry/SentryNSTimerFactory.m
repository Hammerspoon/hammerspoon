#import "SentryNSTimerFactory.h"
#import "SentryInternalDefines.h"

@implementation SentryNSTimerFactory

- (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)interval
                                    repeats:(BOOL)repeats
                                      block:(void (^)(NSTimer *timer))block
{
    SENTRY_ASSERT([NSThread isMainThread],
        @"Timers must be scheduled from the main thread, or they may never fire. See the attribute "
        @"on the declaration in NSTimer.h. See "
        @"https://stackoverflow.com/questions/8304702/"
        @"how-do-i-create-a-nstimer-on-a-background-thread for more info.");
    return [NSTimer scheduledTimerWithTimeInterval:interval repeats:repeats block:block];
}

- (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)ti
                                     target:(id)aTarget
                                   selector:(SEL)aSelector
                                   userInfo:(nullable id)userInfo
                                    repeats:(BOOL)yesOrNo
{
    SENTRY_ASSERT([NSThread isMainThread],
        @"Timers must be scheduled from the main thread, or they may never fire. See the attribute "
        @"on the declaration in NSTimer.h. See "
        @"https://stackoverflow.com/questions/8304702/"
        @"how-do-i-create-a-nstimer-on-a-background-thread for more info.");
    return [NSTimer scheduledTimerWithTimeInterval:ti
                                            target:aTarget
                                          selector:aSelector
                                          userInfo:userInfo
                                           repeats:yesOrNo];
}

@end
