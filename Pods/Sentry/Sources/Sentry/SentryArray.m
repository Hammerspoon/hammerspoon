#import "SentryArray.h"
#import "SentryDateUtils.h"
#import "SentryInternalDefines.h"
#import "SentryNSDictionarySanitize.h"

@implementation SentryArray

+ (NSArray *)sanitizeArray:(NSArray *)array;
{
    NSMutableArray *result = [NSMutableArray array];
    for (id rawValue in array) {
        if ([rawValue isKindOfClass:NSString.class]) {
            [result addObject:rawValue];
        } else if ([rawValue isKindOfClass:NSNumber.class]) {
            [result addObject:rawValue];
        } else if ([rawValue isKindOfClass:NSDictionary.class]) {
            NSDictionary *_Nullable sanitizedDict = sentry_sanitize((NSDictionary *)rawValue);
            if (sanitizedDict == nil) {
                // Adding `nil` to an array is not allowed in Objective-C and raises an
                // `NSInvalidArgumentException`.
                continue;
            }
            [result addObject:SENTRY_UNWRAP_NULLABLE(NSDictionary, sanitizedDict)];
        } else if ([rawValue isKindOfClass:NSArray.class]) {
            [result addObject:[SentryArray sanitizeArray:rawValue]];
        } else if ([rawValue isKindOfClass:NSDate.class]) {
            NSDate *date = (NSDate *)rawValue;
            [result addObject:sentry_toIso8601String(date)];
        } else {
            [result addObject:[rawValue description]];
        }
    }
    return result;
}

@end
