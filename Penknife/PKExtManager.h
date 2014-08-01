#import <Foundation/Foundation.h>
#import "PKExtension.h"

@interface PKExtManager : NSObject

+ (PKExtManager*) sharedExtManager;

- (NSArray*) availableExts;
- (NSArray*) installedExts;
- (NSArray*) allExts;

@end
