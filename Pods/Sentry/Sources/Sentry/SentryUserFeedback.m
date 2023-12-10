#import "SentryUserFeedback.h"
#import "SentryId.h"
#import <Foundation/Foundation.h>

@implementation SentryUserFeedback

- (instancetype)initWithEventId:(SentryId *)eventId
{
    if (self = [super init]) {
        _eventId = eventId;
        _email = @"";
        _name = @"";
        _comments = @"";
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    return @{
        @"event_id" : self.eventId.sentryIdString,
        @"email" : self.email,
        @"name" : self.name,
        @"comments" : self.comments
    };
}

@end
