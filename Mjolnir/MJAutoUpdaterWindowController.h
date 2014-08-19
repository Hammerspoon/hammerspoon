#import <Cocoa/Cocoa.h>

@protocol MJAutoUpdaterWindowControllerDelegate <NSObject>

- (void) userDismissedAutoUpdaterWindow;
- (void) userWantsInstallAtQuit;

@end

@interface MJAutoUpdaterWindowController : NSWindowController

@property (weak) id<MJAutoUpdaterWindowControllerDelegate> delegate;

@property NSString* upcomingVersion;
@property NSString* oldVersion;

- (void) showWindow;

- (void) showCheckingPage;
- (void) showUpToDatePage;
- (void) showFoundPage;
- (void) showErrorPage;

@end
