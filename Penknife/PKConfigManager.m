#import "PKConfigManager.h"

@implementation PKConfigManager

+ (NSString*) configPath {
    return [@"~/.penknife/" stringByStandardizingPath];
}

+ (void) setupConfigDir {
    [[NSFileManager defaultManager] createDirectoryAtPath:[PKConfigManager configPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
}

+ (void) installExtension:(PKExtension*)ext {
    
}

+ (void) uninstallExtension:(PKExtension*)ext {
    
}

@end
