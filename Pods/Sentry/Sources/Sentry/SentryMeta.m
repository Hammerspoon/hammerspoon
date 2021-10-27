#import "SentryMeta.h"

@implementation SentryMeta

// Don't remove the static keyword. If you do the compiler adds the constant name to the global
// symbol table and it might clash with other constants. When keeping the static keyword the
// compiler replaces all occurrences with the value.
static NSString *const versionString = @"7.4.8";
static NSString *const sdkName = @"sentry.cocoa";

+ (NSString *)versionString
{
    return versionString;
}

+ (NSString *)sdkName
{
    return sdkName;
}

@end
