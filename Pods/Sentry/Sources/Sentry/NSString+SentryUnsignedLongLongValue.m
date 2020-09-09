#import "NSString+SentryUnsignedLongLongValue.h"

@implementation NSString (SentryUnsignedLongLongValue)

- (unsigned long long)unsignedLongLongValue
{
    return strtoull([self UTF8String], NULL, 0);
}

@end
