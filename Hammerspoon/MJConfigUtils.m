#import "MJConfigUtils.h"
#import "variables.h"

NSString* MJConfigDir(void) {
    return [MJConfigFileFullPath() stringByDeletingLastPathComponent];
}

NSString* MJConfigDirAbsolute(void) {
    NSString* configDir = MJConfigDir();
    return [[configDir stringByStandardizingPath] stringByResolvingSymlinksInPath];
}

NSString* MJConfigFileFullPath(void) {
    return [MJConfigFile stringByStandardizingPath];
}

