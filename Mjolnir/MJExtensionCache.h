#import <Foundation/Foundation.h>

@interface MJExtensionCache : NSObject <NSSecureCoding>

+ (MJExtensionCache*) cache;
- (void) save;

@property NSNumber* timestamp;
@property NSMutableArray* extensionsAvailable;
@property NSMutableArray* extensionsInstalled;

@end
