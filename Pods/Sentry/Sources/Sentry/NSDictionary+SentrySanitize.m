#import "NSArray+SentrySanitize.h"
#import "NSDate+SentryExtras.h"
#import "NSDictionary+SentrySanitize.h"

@implementation
NSDictionary (SentrySanitize)

- (NSDictionary *)sentry_sanitize
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (id rawKey in self.allKeys) {
        id rawValue = [self objectForKey:rawKey];

        NSString *stringKey;
        if ([rawKey isKindOfClass:NSString.class]) {
            stringKey = rawKey;
        } else {
            stringKey = [rawKey description];
        }

        if ([stringKey hasPrefix:@"__sentry"]) {
            continue; // We don't want to add __sentry variables
        }

        if ([rawValue isKindOfClass:NSString.class]) {
            [dict setValue:rawValue forKey:stringKey];
        } else if ([rawValue isKindOfClass:NSNumber.class]) {
            [dict setValue:rawValue forKey:stringKey];
        } else if ([rawValue isKindOfClass:NSDictionary.class]) {
            [dict setValue:[(NSDictionary *)rawValue sentry_sanitize] forKey:stringKey];
        } else if ([rawValue isKindOfClass:NSArray.class]) {
            [dict setValue:[(NSArray *)rawValue sentry_sanitize] forKey:stringKey];
        } else if ([rawValue isKindOfClass:NSDate.class]) {
            [dict setValue:[(NSDate *)rawValue sentry_toIso8601String] forKey:stringKey];
        } else {
            [dict setValue:[rawValue description] forKey:stringKey];
        }
    }
    return dict;
}

@end
