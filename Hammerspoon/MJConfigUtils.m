#import "MJConfigUtils.h"
#import "variables.h"

NSString* MJConfigDir(void) {
    return [MJConfigFileFullPath() stringByDeletingLastPathComponent];
}

NSString* MJConfigDirAbsolute(void) {
    return [MJConfigDir() stringByResolvingSymlinksInPath];
}

NSString* MJConfigFileFullPath(void) {
    return [MJConfigFile stringByStandardizingPath];
}

