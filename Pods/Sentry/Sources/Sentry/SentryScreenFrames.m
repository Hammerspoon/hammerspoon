#import <Foundation/Foundation.h>
#import <SentryScreenFrames.h>

#if SENTRY_HAS_UIKIT

@implementation SentryScreenFrames

- (instancetype)initWithTotal:(NSUInteger)total frozen:(NSUInteger)frozen slow:(NSUInteger)slow
{
    if (self = [super init]) {
        _total = total;
        _slow = slow;
        _frozen = frozen;
    }

    return self;
}

@end

#endif
