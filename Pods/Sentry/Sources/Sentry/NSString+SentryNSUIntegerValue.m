#import "NSString+SentryNSUIntegerValue.h"

@implementation NSString (SentryNSUIntegerValue)

- (NSUInteger)unsignedLongLongValue
{
    return strtoull([self UTF8String], NULL, 0);
}

@end
