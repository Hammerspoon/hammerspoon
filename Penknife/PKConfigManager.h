#import <Foundation/Foundation.h>

@interface PKConfigManager : NSObject

+ (PKConfigManager*) sharedManager;

+ (NSString*) configPath;
+ (void) setupConfigDir;

@end
