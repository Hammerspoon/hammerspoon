#import "SentryUserFeedback.h"
#import "SentryId.h"
#import <Foundation/Foundation.h>

@implementation SentryUserFeedback

- (instancetype)initWithEventId:(SentryId *)eventId
{
    if (self = [super init]) {
        _eventId = eventId;
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];

    [data setValue:self.eventId.sentryIdString forKey:@"event_id"];
    [data setValue:self.email forKey:@"email"];
    [data setValue:self.name forKey:@"name"];
    [data setValue:self.comments forKey:@"comments"];

    return data;
}

@end
