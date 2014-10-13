#import "MJFileUtils.h"

BOOL MJEnsureDirectoryExists(NSString* dir) {
    return [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                     withIntermediateDirectories:YES
                                                      attributes:nil
                                                           error:NULL];
}
