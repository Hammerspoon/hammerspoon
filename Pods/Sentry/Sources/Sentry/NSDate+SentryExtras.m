#import "NSDate+SentryExtras.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSDate (SentryExtras)

+ (NSDateFormatter *)getIso8601Formatter
{
    static NSDateFormatter *isoFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        isoFormatter = [[NSDateFormatter alloc] init];
        [isoFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
        isoFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        [isoFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    });

    return isoFormatter;
}

+ (NSDate *)sentry_fromIso8601String:(NSString *)string
{
    return [[self.class getIso8601Formatter] dateFromString:string];
}

- (NSString *)sentry_toIso8601String
{
    return [[self.class getIso8601Formatter] stringFromDate:self];
}

@end

NS_ASSUME_NONNULL_END
