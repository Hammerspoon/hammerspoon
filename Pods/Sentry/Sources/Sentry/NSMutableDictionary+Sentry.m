#import "NSMutableDictionary+Sentry.h"

@implementation SentryDictionary

+ (void)mergeEntriesFromDictionary:(NSDictionary *)dictionary
                    intoDictionary:(NSMutableDictionary *)destination
{
    [dictionary enumerateKeysAndObjectsUsingBlock:^(id otherKey, id otherObj, BOOL *stop) {
        if ([otherObj isKindOfClass:NSDictionary.class] &&
            [destination[otherKey] isKindOfClass:NSDictionary.class]) {
            NSMutableDictionary *mergedDict = ((NSDictionary *)destination[otherKey]).mutableCopy;
            [SentryDictionary mergeEntriesFromDictionary:otherObj intoDictionary:mergedDict];
            destination[otherKey] = mergedDict;
            return;
        }

        destination[otherKey] = otherObj;
    }];
}

+ (void)setBoolValue:(nullable NSNumber *)value
              forKey:(NSString *)key
      intoDictionary:(NSMutableDictionary *)destination
{
    if (value != nil) {
        [destination setValue:@([value boolValue]) forKey:key];
    }
}

@end
