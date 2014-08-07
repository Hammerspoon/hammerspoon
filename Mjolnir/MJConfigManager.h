#import <Foundation/Foundation.h>
#import "MJExtension.h"

@interface MJConfigManager : NSObject

+ (NSString*) configPath;
+ (void) setupConfigDir;

+ (NSString*) dirForExtensionName:(NSString*)extname;

+ (void) reload;

@end
