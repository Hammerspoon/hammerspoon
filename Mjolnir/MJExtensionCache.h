#import <Foundation/Foundation.h>

@interface MJExtensionCache : NSObject <NSSecureCoding>

+ (MJExtensionCache*) cache;
- (void) save;

@property NSString* sha;
@property NSMutableArray* extensionsAvailable;
@property NSMutableArray* extensionsInstalled;

@end
