#import "SentryMeta.h"

@implementation SentryMeta

// Don't remove the static keyword. If you do the compiler adds the constant name to the global
// symbol table and it might clash with other constants. When keeping the static keyword the
// compiler replaces all occurrences with the value.
static NSString *versionString = @"8.32.0";
static NSString *sdkName = @"sentry.cocoa";

+ (NSString *)versionString
{
    return versionString;
}

+ (void)setVersionString:(NSString *)value
{
    versionString = value;
}

+ (NSString *)sdkName
{
    return sdkName;
}

+ (void)setSdkName:(NSString *)value
{
    sdkName = value;
}

@end
