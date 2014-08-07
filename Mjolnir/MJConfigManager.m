#import "MJConfigManager.h"
#import "core.h"

@implementation MJConfigManager

+ (NSString*) configPath {
    return [@"~/.mjolnir/" stringByStandardizingPath];
}

+ (void) setupConfigDir {
    [[NSFileManager defaultManager] createDirectoryAtPath:[MJConfigManager configPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
}

+ (NSString*) dirForExtensionName:(NSString*)extname {
    NSString* nameWithDashes = [extname stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    return [[MJConfigManager configPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"ext/%@/", nameWithDashes]];
}

+ (void) reload {
    MJReloadConfig();
}

@end
