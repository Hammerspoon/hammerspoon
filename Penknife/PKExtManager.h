#import <Foundation/Foundation.h>
#import "PKExtension.h"

@interface PKExtManager : NSObject

+ (PKExtManager*) sharedExtManager;

- (void) setup;

@property NSArray* availableExts;
@property NSArray* installedExts;
@property NSString* latestSha;

- (void) updateAvailableExts;

@property BOOL updating;

@end
