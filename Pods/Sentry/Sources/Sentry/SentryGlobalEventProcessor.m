#import "SentryGlobalEventProcessor.h"
#import "SentryLogC.h"

@implementation SentryGlobalEventProcessor

- (instancetype)init
{
    if (self = [super init]) {
        self.processors = [NSMutableArray new];
    }
    return self;
}

- (void)addEventProcessor:(SentryEventProcessor)newProcessor
{
    [self.processors addObject:newProcessor];
}

/**
 * Only for testing
 */
- (void)removeAllProcessors
{
    [self.processors removeAllObjects];
}

- (nullable SentryEvent *)reportAll:(SentryEvent *)event
{
    for (SentryEventProcessor proc in self.processors) {
        event = proc(event);
        if (event == nil) {
            return nil;
        }
    }
    return event;
}

@end
