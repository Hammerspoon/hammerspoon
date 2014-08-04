#import <Foundation/Foundation.h>
#import "PKExtension.h"

@interface PKConfigManager : NSObject

+ (NSString*) configPath;
+ (void) setupConfigDir;

+ (void) installExtension:(PKExtension*)ext;
+ (void) uninstallExtension:(PKExtension*)ext;

+ (NSString*) dirForExt:(PKExtension*)ext;

@end
