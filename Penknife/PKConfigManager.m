#import "PKConfigManager.h"

@implementation PKConfigManager

+ (PKConfigManager*) sharedManager {
    static PKConfigManager* sharedManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[PKConfigManager alloc] init];
    });
    return sharedManager;
}

+ (NSString*) configPath {
    return [@"~/.penknife/" stringByStandardizingPath];
}

+ (void) setupConfigDir {
    [[NSFileManager defaultManager] createDirectoryAtPath:[PKConfigManager configPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
}

@end
