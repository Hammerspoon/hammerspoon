#import <Cocoa/Cocoa.h>

@protocol LVAutoUpdaterWindowControllerDelegate <NSObject>

- (void) userDismissedAutoUpdaterWindow;
- (void) userWantsInstallAtQuit;

@end

@interface MJAutoUpdaterWindowController : NSWindowController

@property (weak) id<LVAutoUpdaterWindowControllerDelegate> delegate;

@property NSString* upcomingVersion;
@property NSString* oldVersion;

- (void) showWindow;

- (void) showCheckingPage;
- (void) showUpToDatePage;
- (void) showFoundPage;
- (void) showErrorPage;

@end
