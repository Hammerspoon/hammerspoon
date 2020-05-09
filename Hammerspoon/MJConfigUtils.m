#import "MJConfigUtils.h"
#import "variables.h"

NSString* MJConfigDir(void) {
    return [MJConfigFileFullPath() stringByDeletingLastPathComponent];
}

NSString* MJConfigFileFullPath(void) {
    return [[MJConfigFile stringByStandardizingPath] stringByResolvingSymlinksInPath];
}
