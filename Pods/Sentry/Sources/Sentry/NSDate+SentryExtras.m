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

+ (NSDateFormatter *)getIso8601FormatterWithMillisecondPrecision
{
    static NSDateFormatter *isoFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        isoFormatter = [[NSDateFormatter alloc] init];
        [isoFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
        isoFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        [isoFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
    });

    return isoFormatter;
}

+ (NSDate *)sentry_fromIso8601String:(NSString *)string
{
    NSDate *date = [[self.class getIso8601FormatterWithMillisecondPrecision] dateFromString:string];
    if (nil == date) {
        // Parse date with low precision formatter for backward compatible
        return [[self.class getIso8601Formatter] dateFromString:string];
    } else {
        return date;
    }
}

- (NSString *)sentry_toIso8601String
{
    return [[self.class getIso8601FormatterWithMillisecondPrecision] stringFromDate:self];
}

@end

NS_ASSUME_NONNULL_END
