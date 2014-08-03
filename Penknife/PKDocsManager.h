#import <Foundation/Foundation.h>

@interface PKDocsManager : NSObject

+ (PKDocsManager*) sharedManager;

+ (NSURL*) userLocation;
+ (void) copyDocsIfNeeded;

@end
