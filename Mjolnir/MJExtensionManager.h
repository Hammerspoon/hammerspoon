#import <Foundation/Foundation.h>
#import "MJExtensionCache.h"

extern NSString* MJExtensionsUpdatedNotification;

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

- (void) upgrade:(NSMutableArray*)toupgrade
         install:(NSMutableArray*)toinstall
       uninstall:(NSMutableArray*)touninstall;

@end
