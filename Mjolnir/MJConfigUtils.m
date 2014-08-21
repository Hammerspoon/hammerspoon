#import "MJConfigUtils.h"
#import "core.h"

NSString* MJConfigPath(void) {
    return [@"~/.mjolnir/" stringByStandardizingPath];
}

void MJConfigSetupDir(void) {
    [[NSFileManager defaultManager] createDirectoryAtPath:MJConfigPath()
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
}

NSString* MJConfigDirForExtensionName(NSString* extname) {
    NSString* nameWithDashes = [extname stringByReplacingOccurrencesOfString:@"." withString:@"/"];
    return [MJConfigPath() stringByAppendingPathComponent:[NSString stringWithFormat:@"ext/%@/", nameWithDashes]];
}
