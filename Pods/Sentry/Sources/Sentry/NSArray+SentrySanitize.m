#import "NSArray+SentrySanitize.h"
#import "NSDate+SentryExtras.h"
#import "NSDictionary+SentrySanitize.h"

@implementation
NSArray (SentrySanitize)

- (NSArray *)sentry_sanitize
{
    NSMutableArray *array = [NSMutableArray array];
    for (id rawValue in self) {

        if ([rawValue isKindOfClass:NSString.class]) {
            [array addObject:rawValue];
        } else if ([rawValue isKindOfClass:NSNumber.class]) {
            [array addObject:rawValue];
        } else if ([rawValue isKindOfClass:NSDictionary.class]) {
            [array addObject:[(NSDictionary *)rawValue sentry_sanitize]];
        } else if ([rawValue isKindOfClass:NSArray.class]) {
            [array addObject:[(NSArray *)rawValue sentry_sanitize]];
        } else if ([rawValue isKindOfClass:NSDate.class]) {
            [array addObject:[(NSDate *)rawValue sentry_toIso8601String]];
        } else {
            [array addObject:[rawValue description]];
        }
    }
    return array;
}

@end
