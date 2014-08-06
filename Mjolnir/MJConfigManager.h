#import <Foundation/Foundation.h>
#import "MJExtension.h"

@interface MJConfigManager : NSObject

+ (NSString*) configPath;
+ (void) setupConfigDir;

+ (void) downloadExtension:(NSString*)url handler:(void(^)(NSError* err, NSData* data))handler;
+ (BOOL) verifyData:(NSData*)tgzdata sha:(NSString*)sha error:(NSError*__autoreleasing*)error;
+ (BOOL) untarData:(NSData*)tardata intoDirectory:(NSString*)dir error:(NSError*__autoreleasing*)error;
+ (NSString*) dirForExtensionName:(NSString*)extname;

+ (void) reload;

@end
