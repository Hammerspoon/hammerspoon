#import <Foundation/Foundation.h>
#import "MJExtension.h"

@interface MJConfigManager : NSObject

+ (NSString*) configPath;
+ (void) setupConfigDir;

+ (void) installExtension:(MJExtension*)ext;
+ (void) uninstallExtension:(MJExtension*)ext;

+ (NSString*) dirForExt:(MJExtension*)ext;

+ (void) reload;

@end
