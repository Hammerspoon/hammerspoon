#import <Foundation/Foundation.h>
#import "PKExtension.h"

@interface PKExtManager : NSObject

+ (PKExtManager*) sharedExtManager;

- (void) setup;

@property NSArray* availableExts;
@property NSArray* installedExts;

- (void) updateAvailableExts;

@end
