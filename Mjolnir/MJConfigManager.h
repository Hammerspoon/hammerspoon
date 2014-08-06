#import <Foundation/Foundation.h>
#import "MJExtension.h"

@interface MJConfigManager : NSObject

+ (NSString*) configPath;
+ (void) setupConfigDir;

+ (void) downloadExtension:(NSString*)url handler:(void(^)(NSError* err, NSData* data))handler;
+ (NSString*) saveDataToTempFile:(NSData*)tgz_data error:(NSError*__autoreleasing*)error;
+ (BOOL) verifyFile:(NSString*)path sha:(NSString*)sha;
+ (BOOL) untarFile:(NSString*)tarfile intoDirectory:(NSString*)dir error:(NSError*__autoreleasing*)error;
+ (NSString*) dirForExtensionName:(NSString*)extname;

+ (void) reload;

@end
