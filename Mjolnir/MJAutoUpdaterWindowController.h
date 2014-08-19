#import <Cocoa/Cocoa.h>
#import "MJUpdate.h"

@protocol MJAutoUpdaterWindowControllerDelegate <NSObject>

- (void) userDismissedAutoUpdaterWindow;

@end

@interface MJAutoUpdaterWindowController : NSWindowController

@property (weak) id<MJAutoUpdaterWindowControllerDelegate> delegate;

@property MJUpdate* update;
@property NSString* error;

- (void) showCheckingPage;
- (void) showUpToDatePage;
- (void) showFoundPage;
- (void) showErrorPage;

@end
