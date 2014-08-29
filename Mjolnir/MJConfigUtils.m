#import "MJConfigUtils.h"

NSString* MJConfigPath(void) {
    return [@"~/.mjolnir/" stringByStandardizingPath];
}

void MJConfigEnsureDirExists(void) {
    [[NSFileManager defaultManager] createDirectoryAtPath:MJConfigPath()
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
}
