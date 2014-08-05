#import "MJMainWindowController.h"
#import "MJTabController.h"
#import "MJGeneralTabController.h"
#import "MJReplTabController.h"
#import "MJExtensionsTabController.h"

@interface MJMainWindowController ()
@property (weak) IBOutlet NSTabView* tabView;
@property NSMutableArray* tabControllers;
@property NSMutableDictionary* tabIcons;
@end

@implementation MJMainWindowController

+ (MJMainWindowController*) sharedMainWindowController {
    static MJMainWindowController* sharedMainWindowController;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMainWindowController = [[MJMainWindowController alloc] init];
    });
    return sharedMainWindowController;
}

- (NSString*) windowNibName { return @"MainWindow"; }

- (void) showWindow:(id)sender {
    if (![[self window] isVisible])
        [[self window] center];
    
    [super showWindow:sender];
}

- (void) addTabController:(id<MJTabController>)controller {
    [self.tabControllers addObject: controller];
    
    NSTabViewItem* tabitem = [[NSTabViewItem alloc] initWithIdentifier:[controller title]];
    [tabitem setView: [controller view]];
    [tabitem setInitialFirstResponder:[controller initialFirstResponder]];
    [[controller view] setFrame:[self.tabView bounds]];
    [self.tabView addTabViewItem:tabitem];
    
    NSToolbarItem* toolbaritem = [[NSToolbarItem alloc] initWithItemIdentifier:[controller title]];
    [toolbaritem setLabel:[controller title]];
    [toolbaritem setImage:[controller icon]];
    [toolbaritem setTarget:self];
    [toolbaritem setAction:@selector(switchToTab:)];
    [self.tabIcons setObject:toolbaritem forKey:[controller title]];
    NSToolbar* toolbar = [[self window] toolbar];
    [toolbar insertItemWithItemIdentifier:[controller title] atIndex:[[toolbar items] count]];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar {
    return [self.tabIcons allValues];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
    return [self.tabIcons objectForKey: itemIdentifier];
}

- (void)windowDidLoad {
    self.tabControllers = [NSMutableArray array];
    self.tabIcons = [NSMutableDictionary dictionary];
    
    [self addTabController:[[MJGeneralTabController alloc] init]];
    [self addTabController:[[MJReplTabController alloc] init]];
    [self addTabController:[[MJExtensionsTabController alloc] init]];
    
    [[[self window] toolbar] setSelectedItemIdentifier:[[self.tabControllers firstObject] title]];
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
