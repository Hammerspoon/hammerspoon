#import <Foundation/Foundation.h>
#import "PKExtension.h"

@interface PKExtManager : NSObject

+ (PKExtManager*) sharedExtManager;

- (void) setup;

- (NSArray*) availableExts;
- (NSArray*) installedExts;
- (NSArray*) allExts;

- (void) updateAvailableExts;

@end
