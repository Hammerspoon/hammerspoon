#import "SentryEnvelopeHeaderHelper.h"
#import "SentrySDKInternal.h"
#import "SentrySwift.h"

@implementation SentryEnvelopeHeaderHelper

+ (SentryIdWrapper *)headerIdFromEvent:(SentryEvent *)event
{
    return [[SentryIdWrapper alloc] initWithId:event.eventId.sentryIdString];
}

@end
