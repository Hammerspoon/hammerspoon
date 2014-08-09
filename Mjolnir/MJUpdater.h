#import <Foundation/Foundation.h>

@interface MJUpdater : NSObject

@property NSString* newerVersion;
@property NSString* yourVersion;

+ (void) checkForUpdate:(void(^)(MJUpdater* updater))handler;
- (void) install:(void(^)(NSString* error, NSString* reason))handler;

@end
