#import "MJConfigUtils.h"
#import "core.h"

NSString* MJConfigPath(void) {
    return [@"~/.mjolnir/" stringByStandardizingPath];
}

void MJConfigEnsureDirExists(void) {
    [[NSFileManager defaultManager] createDirectoryAtPath:MJConfigPath()
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
}

NSString* MJConfigExtensionDir(NSString* extname) {
    NSString* nameWithDashes = [extname stringByReplacingOccurrencesOfString:@"." withString:@"/"];
    return [MJConfigPath() stringByAppendingPathComponent:[NSString stringWithFormat:@"ext/%@/", nameWithDashes]];
}
