#import <Foundation/Foundation.h>
#import "PKExtensionCache.h"

extern NSString* PKExtensionsUpdatedNotification;

@interface PKExtManager : NSObject

+ (PKExtManager*) sharedExtManager;

- (void) setup;
- (void) update;

@property PKExtensionCache* cache;
@property BOOL updating;

@end
