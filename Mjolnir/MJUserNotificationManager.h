#import <Foundation/Foundation.h>

@interface MJUserNotificationManager : NSObject

+ (MJUserNotificationManager*) sharedManager;

- (void) sendNotification:(NSString*)title handler:(dispatch_block_t)handler;

@end
