#import "MJUserNotificationManager.h"

@interface MJUserNotificationManager () <NSUserNotificationCenterDelegate>
@property NSMutableDictionary* callbacks;
@end

@implementation MJUserNotificationManager

+ (MJUserNotificationManager*) sharedManager {
    static MJUserNotificationManager* sharedManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[MJUserNotificationManager alloc] init];
        sharedManager.callbacks = [NSMutableDictionary dictionary];
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:sharedManager];
    });
    return sharedManager;
}

- (void) sendNotification:(NSString*)title handler:(dispatch_block_t)handler {
    NSUserNotification* note = [[NSUserNotification alloc] init];
    note.title = title;
    [self.callbacks setObject:[handler copy] forKey:note];
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification: note];
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification: notification]; // is this unnecessary? can't tell, docs suck.
    
    dispatch_block_t callback = [self.callbacks objectForKey: notification];
    if (callback)
        callback();
    
    [self.callbacks removeObjectForKey: notification];
}

- (BOOL) userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    return YES;
}

@end
