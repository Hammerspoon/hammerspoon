#import "SentryNSDictionarySanitize.h"
#import "NSArray+SentrySanitize.h"
#import "SentryDateUtils.h"

NSDictionary *_Nullable sentry_sanitize(NSDictionary *_Nullable dictionary)
{
    if (dictionary == nil) {
        return nil;
    }

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (id rawKey in dictionary.allKeys) {
        id rawValue = [dictionary objectForKey:rawKey];

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
            NSDictionary *innerDict = (NSDictionary *)rawValue;
            [dict setValue:sentry_sanitize(innerDict) forKey:stringKey];
        } else if ([rawValue isKindOfClass:NSArray.class]) {
            [dict setValue:[SentryArray sanitizeArray:rawValue] forKey:stringKey];
        } else if ([rawValue isKindOfClass:NSDate.class]) {
            NSDate *date = (NSDate *)rawValue;
            [dict setValue:sentry_toIso8601String(date) forKey:stringKey];
        } else {
            [dict setValue:[rawValue description] forKey:stringKey];
        }
    }
    return dict;
}
