#import <Cocoa/Cocoa.h>
#import "MJUpdate.h"

@protocol MJAutoUpdaterWindowControllerDelegate <NSObject>

- (void) userDismissedAutoUpdaterWindow;
- (void) userWantsInstallAtQuit;

@end

@interface MJAutoUpdaterWindowController : NSWindowController

@property (weak) id<MJAutoUpdaterWindowControllerDelegate> delegate;

@property MJUpdate* update;

- (void) showWindow;

- (void) showCheckingPage;
- (void) showUpToDatePage;
- (void) showFoundPage;
- (void) showErrorPage;

@end
