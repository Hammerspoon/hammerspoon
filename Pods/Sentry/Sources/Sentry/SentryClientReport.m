#import "SentryClientReport.h"
#import "SentryCurrentDate.h"
#import <Foundation/Foundation.h>
#import <SentryDiscardedEvent.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryClientReport

- (instancetype)initWithDiscardedEvents:(NSArray<SentryDiscardedEvent *> *)discardedEvents
{
    if (self = [super init]) {
        _timestamp = [SentryCurrentDate date];
        _discardedEvents = discardedEvents;
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableArray<NSDictionary<NSString *, id> *> *events =
        [[NSMutableArray alloc] initWithCapacity:self.discardedEvents.count];
    for (SentryDiscardedEvent *event in self.discardedEvents) {
        [events addObject:[event serialize]];
    }

    return
        @{ @"timestamp" : @(self.timestamp.timeIntervalSince1970), @"discarded_events" : events };
}

@end

NS_ASSUME_NONNULL_END
