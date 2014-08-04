#import <Foundation/Foundation.h>
#import "MJExtensionCache.h"

extern NSString* PKExtensionsUpdatedNotification;

@interface MJExtensionManager : NSObject

+ (MJExtensionManager*) sharedManager;

- (void) setup;
- (void) update;
- (void) loadInstalledModules;

@property BOOL updating;

@property NSArray* extsNotInstalled;
@property NSArray* extsUpToDate;
@property NSArray* extsNeedingUpgrade;
@property NSArray* extsRemovedRemotely;

- (void) upgrade:(NSArray*)upgrade
         install:(NSArray*)install
       uninstall:(NSArray*)uninstall;

@end
