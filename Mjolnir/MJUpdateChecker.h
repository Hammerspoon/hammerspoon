#import <Foundation/Foundation.h>

@interface MJUpdateChecker : NSObject

+ (MJUpdateChecker*) sharedChecker;

- (void) setup;
- (void) checkForUpdatesInBackground;

@property BOOL checkingEnabled;

@end
