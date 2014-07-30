#import "PKMainWindowController.h"

@interface PKMainWindowController ()
@property (weak) IBOutlet NSTabView* tabView;
@end

@implementation PKMainWindowController

- (NSString*) windowNibName { return @"MainWindow"; }

- (void) showWindow:(id)sender {
    if (![[self window] isVisible])
        [[self window] center];
    
    [super showWindow:sender];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    [[[self window] toolbar] setSelectedItemIdentifier:@"settings"];
}

- (NSArray*) toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
    return [[toolbar items] valueForKeyPath:@"itemIdentifier"];
}

- (IBAction) switchToTab:(NSToolbarItem*)sender {
    [self showTab:[sender itemIdentifier]];
}

- (void) showTab:(NSString*)tab {
    [self.tabView selectTabViewItemWithIdentifier:tab];
    NSTabViewItem* item = [self.tabView selectedTabViewItem];
    [[[item initialFirstResponder] window] makeFirstResponder:[item initialFirstResponder]];
}

- (void) showAtTab:(NSString*)tab {
    [self showWindow:self];
    [[[self window] toolbar] setSelectedItemIdentifier:tab];
    [self showTab:tab];
}

@end
