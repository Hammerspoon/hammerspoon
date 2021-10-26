#import "SentryDisplayLinkWrapper.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

@implementation SentryDisplayLinkWrapper {
    CADisplayLink *displayLink;
}

- (CFTimeInterval)timestamp
{
    return displayLink.timestamp;
}

- (void)linkWithTarget:(id)target selector:(SEL)sel
{
    displayLink = [CADisplayLink displayLinkWithTarget:target selector:sel];
    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)invalidate
{
    [displayLink invalidate];
}

@end

#endif
