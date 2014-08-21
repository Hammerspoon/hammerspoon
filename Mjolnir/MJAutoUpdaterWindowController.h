#import <Cocoa/Cocoa.h>
#import "MJUpdate.h"

@interface MJAutoUpdaterWindowController : NSWindowController

@property MJUpdate* update;
@property NSString* error;

- (void) showCheckingPage;
- (void) showUpToDatePage;
- (void) showFoundPage;
- (void) showErrorPage;

@end
