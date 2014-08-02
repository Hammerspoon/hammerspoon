#import <Foundation/Foundation.h>

extern NSString* PKExtensionsUpdatedNotification;

@interface PKExtManager : NSObject

+ (PKExtManager*) sharedExtManager;

- (void) setup;

@property NSArray* availableExts;
@property NSArray* installedExts;
@property NSString* latestSha;

- (void) updateAvailableExts;

@property BOOL updating;

@end
