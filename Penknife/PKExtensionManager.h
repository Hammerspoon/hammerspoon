#import <Foundation/Foundation.h>
#import "PKExtensionCache.h"

extern NSString* PKExtensionsUpdatedNotification;

@interface PKExtensionManager : NSObject

+ (PKExtensionManager*) sharedManager;

- (void) setup;
- (void) update;

@property PKExtensionCache* cache;
@property BOOL updating;

@end
