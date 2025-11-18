#import "SentryEventSwiftHelper.h"
#import "SentryEvent.h"
#import "SentrySwift.h"

// This helper is to bridge Swift and ObjC when building with SPM.
// SPM cannot use Swift types in public ObjC APIs. Since SentryId
// is Swift and SentryEvent is ObjC, Swift code built with SPM
// cannot modify the eventId. This helper makes that possible.
// Other solutions involve a force cast, forward declaring in ObjC
// or re-writing in Swift. We will explore those in the future, but for
// now this enables CI to build with SPM.
@implementation SentryEventSwiftHelper

+ (void)setEventIdString:(NSString *)idString event:(SentryEvent *)event
{
    event.eventId = [[SentryId alloc] initWithUUIDString:idString];
}

+ (NSString *)getEventIdString:(SentryEvent *)event
{
    return event.eventId.sentryIdString;
}

@end
