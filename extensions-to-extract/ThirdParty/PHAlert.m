#import "helpers.h"

static NSMutableArray* visibleAlerts;

@interface PHAlert : NSWindowController
@end

@interface PHAlert ()

@property IBOutlet NSTextField* textField;
@property IBOutlet NSBox* box;

@end

@implementation PHAlert

void PHShowAlert(NSString* oneLineMsg, CGFloat duration) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        visibleAlerts = [NSMutableArray array];
    });
    
    CGFloat absoluteTop;
    
    NSScreen* currentScreen = [NSScreen mainScreen];
    
    if ([visibleAlerts count] == 0) {
        CGRect screenRect = [currentScreen frame];
        absoluteTop = screenRect.size.height / 1.55; // pretty good spot
    }
    else {
        PHAlert* ctrl = [visibleAlerts lastObject];
        absoluteTop = NSMinY([[ctrl window] frame]) - 3.0;
    }
    
    if (absoluteTop <= 0)
        absoluteTop = NSMaxY([currentScreen visibleFrame]);
    
    PHAlert* alert = [[PHAlert alloc] init];
    [alert show:oneLineMsg duration:duration pushDownBy:absoluteTop];
    [visibleAlerts addObject:alert];
}

- (NSString*) windowNibName {
    return @"alert";
}

- (void) windowDidLoad {
    self.window.styleMask = NSBorderlessWindowMask;
    self.window.backgroundColor = [NSColor clearColor];
    self.window.opaque = NO;
    self.window.level = NSFloatingWindowLevel;
    self.window.ignoresMouseEvents = YES;
    self.window.animationBehavior = (/* TODO: make me a variable */ YES ? NSWindowAnimationBehaviorAlertPanel : NSWindowAnimationBehaviorNone);
//    self.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary;
}

- (void) show:(NSString*)oneLineMsg duration:(CGFloat)duration pushDownBy:(CGFloat)adjustment {
    NSDisableScreenUpdates();
    
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.01];
    [[[self window] animator] setAlphaValue:1.0];
    [NSAnimationContext endGrouping];
    
    [self useTitleAndResize:[oneLineMsg description]];
    [self setFrameWithAdjustment:adjustment];
    [self showWindow:self];
    [self performSelector:@selector(fadeWindowOut) withObject:nil afterDelay:duration];
    
    NSEnableScreenUpdates();
}

- (void) setFrameWithAdjustment:(CGFloat)pushDownBy {
    NSScreen* currentScreen = [NSScreen mainScreen];
    CGRect screenRect = [currentScreen frame];
    CGRect winRect = [[self window] frame];
    
    winRect.origin.x = (screenRect.size.width / 2.0) - (winRect.size.width / 2.0);
    winRect.origin.y = pushDownBy - winRect.size.height;
    
    [self.window setFrame:winRect display:NO];
}

- (void) fadeWindowOut {
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.15];
    [[[self window] animator] setAlphaValue:0.0];
    [NSAnimationContext endGrouping];
    
    [self performSelector:@selector(closeAndResetWindow) withObject:nil afterDelay:0.15];
}

- (void) closeAndResetWindow {
    [[self window] orderOut:nil];
    [[self window] setAlphaValue:1.0];
    
    [visibleAlerts removeObject: self];
}

- (void) useTitleAndResize:(NSString*)title {
    [self window]; // sigh; required in case nib hasnt loaded yet
    [[self window] setTitle:title];
    
    self.textField.stringValue = title;
    [self.textField sizeToFit];
    
	NSRect windowFrame = [[self window] frame];
	windowFrame.size.width = [self.textField frame].size.width + 32.0;
	windowFrame.size.height = [self.textField frame].size.height + 24.0;
	[[self window] setFrame:windowFrame display:YES];
}

@end
