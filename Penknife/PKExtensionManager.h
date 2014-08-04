#import <Foundation/Foundation.h>
#import "PKExtensionCache.h"

extern NSString* PKExtensionsUpdatedNotification;

@interface PKExtensionManager : NSObject

+ (PKExtensionManager*) sharedManager;

- (void) setup;
- (void) update;

@property BOOL updating;

@property NSArray* extsNotInstalled;
@property NSArray* extsUpToDate;
@property NSArray* extsNeedingUpgrade;
@property NSArray* extsRemovedRemotely;

- (void) upgrade:(NSArray*)upgrade
         install:(NSArray*)install
       uninstall:(NSArray*)uninstall;

@end
