#import <Foundation/Foundation.h>

@interface PKExtensionCache : NSObject <NSSecureCoding>

+ (PKExtensionCache*) cache;
- (void) save;

@property NSString* sha;
@property NSMutableArray* extensionsAvailable;
@property NSMutableArray* extensionsInstalled;

@end
