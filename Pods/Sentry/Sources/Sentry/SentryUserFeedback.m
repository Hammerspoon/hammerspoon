#import "SentryUserFeedback.h"
#import "SentrySwift.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
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
#pragma clang diagnostic pop
