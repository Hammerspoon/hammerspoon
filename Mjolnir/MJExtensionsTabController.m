#import "MJExtensionsTabController.h"
#import "MJExtensionManager.h"
#import "MJExtension.h"

#define MJCheckForExtensionUpdatesInterval (60.0 * 60.0 * 24.0)

#define MJSkipRecommendRestartAlertKey @"MJSkipRecommendRestartAlertKey"

typedef NS_ENUM(NSUInteger, MJCacheItemType) {
    MJCacheItemTypeHeader,
    MJCacheItemTypeNotInstalled,
    MJCacheItemTypeUpToDate,
    MJCacheItemTypeNeedsUpgrade,
    MJCacheItemTypeRemovedRemotely,
};

// oh swift, I do wish you were here already
@interface MJCacheItem : NSObject
@property MJCacheItemType type;
@property MJExtension* ext;
@property NSString* header;
@property BOOL actionize;
@property BOOL actionizing;
@end
@implementation MJCacheItem
+ (MJCacheItem*) header:(NSString*)title {
    MJCacheItem* item = [[MJCacheItem alloc] init];
    item.type = MJCacheItemTypeHeader;
    item.header = title;
    return item;
}
+ (MJCacheItem*) ext:(MJExtension*)ext type:(MJCacheItemType)type {
    MJCacheItem* item = [[MJCacheItem alloc] init];
    item.type = type;
    item.ext = ext;
    return item;
}
- (NSString*) displayVersion {
    if (self.ext.previous)
        return [NSString stringWithFormat:@"%@ (current version: %@)", self.ext.version, self.ext.previous.version];
    else
        return self.ext.version;
}
- (NSString*) currentVersion {
    if (self.ext.previous)
        return self.ext.previous.version;
    else
        return self.ext.version;
}
- (NSAttributedString*) details {
    CGFloat fontsize = 12.0;
    NSDictionary* normal = @{NSFontAttributeName: [NSFont systemFontOfSize:fontsize]};
    NSDictionary* bold = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:fontsize]};
    NSDictionary* website = @{NSFontAttributeName: [NSFont systemFontOfSize:fontsize], NSLinkAttributeName: [NSURL URLWithString:self.ext.website]};
    
    NSMutableAttributedString* mastr = [[NSMutableAttributedString alloc] init];
    [mastr beginEditing];
    
    void(^add)(NSString* title, NSString* sep, NSString* body, NSDictionary* attrs) = ^(NSString* title, NSString* sep, NSString* body, NSDictionary* attrs) {
        [mastr appendAttributedString:[[NSAttributedString alloc] initWithString:title attributes:bold]];
        [mastr appendAttributedString:[[NSAttributedString alloc] initWithString:body attributes:attrs]];
        [mastr appendAttributedString:[[NSAttributedString alloc] initWithString:sep attributes:attrs]];
    };
    
    NSString* deps;
    if ([self.ext.dependencies count] > 0)
        deps = [self.ext.dependencies componentsJoinedByString:@", "];
    else
        deps = @"<none>";
    
    add(@"Name: ", @"\n", self.ext.name, normal);
    add(@"Version: ", @"\n", self.ext.version, normal);
    add(@"License: ", @"\n\n", self.ext.license, normal);
    add(@"", @"\n\n", self.ext.website, website);
    add(@"", @"\n\n", self.ext.desc, normal);
    add(@"Depends on: ", @"\n\n", deps, normal);
    add(@"Changes:\n\n", @"\n\n", self.ext.changelog, normal);
    
    [mastr endEditing];
    
    return mastr;
}
@end

@interface MJExtensionsTabController () <NSTableViewDataSource, NSTableViewDelegate, NSSplitViewDelegate>
@property (weak) IBOutlet NSTableView* extsTable;
@property NSArray* cache;
@property BOOL hasActionsToApply;
@property MJCacheItem* selectedCacheItem;
@end

@implementation MJExtensionsTabController

@synthesize initialFirstResponder;
- (NSString*) nibName { return @"ExtensionsTab"; }
- (NSString*) title   { return @"Extensions"; }
- (NSImage*)  icon    { return [NSImage imageNamed:@"Extensions"]; }

- (void) awakeFromNib {
    [NSTimer scheduledTimerWithTimeInterval:MJCheckForExtensionUpdatesInterval
                                     target:self
                                   selector:@selector(checkForUpdatesTimerFired:)
                                   userInfo:nil
                                    repeats:YES];
    
    [self rebuildCache];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(extensionsUpdated:)
                                                 name:MJExtensionsUpdatedNotification
                                               object:nil];
}

- (void) checkForUpdatesTimerFired:(NSTimer*)timer {
    if (!self.hasActionsToApply)
        [[MJExtensionManager sharedManager] update];
}

- (void) rebuildCache {
    NSMutableArray* cache = [NSMutableArray array];
    
    if ([[MJExtensionManager sharedManager].extsNotInstalled count] > 0) {
        [cache addObject: [MJCacheItem header: @"Not Installed"]];
        for (MJExtension* ext in [MJExtensionManager sharedManager].extsNotInstalled)
            [cache addObject: [MJCacheItem ext:ext type:MJCacheItemTypeNotInstalled]];
    }
    
    if ([[MJExtensionManager sharedManager].extsUpToDate count] > 0) {
        [cache addObject: [MJCacheItem header: @"Installed - Up to Date"]];
        for (MJExtension* ext in [MJExtensionManager sharedManager].extsUpToDate)
            [cache addObject: [MJCacheItem ext:ext type:MJCacheItemTypeUpToDate]];
    }
    
    if ([[MJExtensionManager sharedManager].extsNeedingUpgrade count] > 0) {
        [cache addObject: [MJCacheItem header: @"Installed - Upgrade Available"]];
        for (MJExtension* ext in [MJExtensionManager sharedManager].extsNeedingUpgrade)
            [cache addObject: [MJCacheItem ext:ext type:MJCacheItemTypeNeedsUpgrade]];
    }
    
    if ([[MJExtensionManager sharedManager].extsRemovedRemotely count] > 0) {
        [cache addObject: [MJCacheItem header: @"Installed - No longer offered publicly!"]];
        for (MJExtension* ext in [MJExtensionManager sharedManager].extsRemovedRemotely)
            [cache addObject: [MJCacheItem ext:ext type:MJCacheItemTypeRemovedRemotely]];
    }
    
    self.hasActionsToApply = NO;
    self.cache = cache;
    self.selectedCacheItem = nil;
    [self.extsTable reloadData];
}

- (void) extensionsUpdated:(NSNotification*)note {
    [self rebuildCache];
}

- (MJExtensionManager*) extManager {
    // for use with binding progress animator
    return [MJExtensionManager sharedManager];
}

- (IBAction) updateExtensions:(id)sender {
    [[MJExtensionManager sharedManager] update];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [self.cache count];
}

- (NSTextField*) headerRow:(NSTableView*)tableView {
    NSTextField *result = [tableView makeViewWithIdentifier:@"header" owner:self];
    if (!result) {
        result = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 100, 0)];
        [result setBordered:NO];
        [result setBezelStyle:NSTextFieldRoundedBezel];
        [result setEditable:NO];
        result.identifier = @"header";
    }
    return result;
}

- (NSTextField*) attrRow:(NSTableView*)tableView {
    NSTextField *result = [tableView makeViewWithIdentifier:@"attr" owner:self];
    if (!result) {
        result = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 100, 0)];
        [result setDrawsBackground:NO];
        [result setBordered:NO];
        [result setEditable:NO];
        result.identifier = @"attr";
    }
    return result;
}

- (NSButton*) actionRow:(NSTableView*)tableView {
    NSButton* button = [tableView makeViewWithIdentifier:@"useraction" owner:self];
    if (!button) {
        button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 100, 0)];
        [button setButtonType:NSSwitchButton];
        [button setTitle:@""];
        button.identifier = @"useraction";
        button.target = self;
        button.action = @selector(toggleExtAction:);
    }
    return button;
}

- (NSProgressIndicator*) progressRow:(NSTableView*)tableView {
    NSProgressIndicator* progress = [tableView makeViewWithIdentifier:@"progress" owner:self];
    if (!progress) {
        progress = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 100, 0)];
        progress.identifier = @"progress";
        [progress setIndeterminate:YES];
        [progress setStyle:NSProgressIndicatorSpinningStyle];
        [progress setControlSize:NSSmallControlSize];
        [progress startAnimation:nil];
    }
    return progress;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    MJCacheItem* item = [self.cache objectAtIndex:row];
    
    if (item.type == MJCacheItemTypeHeader) {
        NSTextField* header = [self headerRow:tableView];
        header.stringValue = item.header;
        return header;
    }
    else if ([[tableColumn identifier] isEqualToString: @"name"]) {
        NSTextField* attr = [self attrRow:tableView];
        attr.stringValue = [NSString stringWithFormat:@"%@ (%@)", item.ext.name, [item currentVersion]];
        return attr;
    }
    else if ([[tableColumn identifier] isEqualToString: @"action"]) {
        if (item.actionizing) {
            return [self progressRow:tableView];
        }
        else {
            NSString* title;
            switch (item.type) {
                case MJCacheItemTypeNeedsUpgrade:    title = @"Upgrade"; break;
                case MJCacheItemTypeNotInstalled:    title = @"Install"; break;
                case MJCacheItemTypeRemovedRemotely: title = @"Uninstall"; break;
                case MJCacheItemTypeUpToDate:        title = @"Uninstall"; break;
                default: break;
            }
            NSButton* action = [self actionRow:tableView];
            action.title = title;
            action.state = item.actionize ? NSOnState : NSOffState;
            return action;
        }
    }
    
    return nil; // unreachable (I hope)
}

- (void) applyChanges {
    NSMutableArray* upgrade = [NSMutableArray array];
    NSMutableArray* install = [NSMutableArray array];
    NSMutableArray* uninstall = [NSMutableArray array];
    
    for (MJCacheItem* item in self.cache) {
        if (!item.actionize)
            continue;
        
        item.actionizing = YES;
        
        switch (item.type) {
            case MJCacheItemTypeHeader: continue;
            case MJCacheItemTypeNeedsUpgrade:    [upgrade addObject: item.ext]; break;
            case MJCacheItemTypeNotInstalled:    [install addObject: item.ext]; break;
            case MJCacheItemTypeRemovedRemotely: [uninstall addObject: item.ext]; break;
            case MJCacheItemTypeUpToDate:        [uninstall addObject: item.ext]; break;
        }
    }
    
    [self.extsTable reloadData];
    
    [[MJExtensionManager sharedManager] upgrade:upgrade
                                        install:install
                                      uninstall:uninstall];
}

- (void) applyChangesAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    BOOL skipNextTime = ([[alert suppressionButton] state] == NSOnState);
    [[NSUserDefaults standardUserDefaults] setBool:skipNextTime forKey:MJSkipRecommendRestartAlertKey];
    
    [self applyChanges];
}

- (IBAction) applyActions:(NSButton*)sender {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:MJSkipRecommendRestartAlertKey]) {
        [self applyChanges];
        return;
    }
    
    BOOL recommendRestart = NO;
    for (MJCacheItem* item in self.cache) {
        if (!item.actionize)
            continue;
        
        if (item.type == MJCacheItemTypeRemovedRemotely || item.type == MJCacheItemTypeUpToDate)
            recommendRestart = YES;
    }
    
    if (!recommendRestart) {
        [self applyChanges];
        return;
    }
    
    NSAlert* alert = [[NSAlert alloc] init];
    [alert setAlertStyle: NSCriticalAlertStyle];
    [alert setMessageText: @"Restart recommended"];
    [alert setInformativeText: @"When you uninstall or upgrade an extension, you may need to restart Mjolnir; otherwise, strange things may happen."];
    [alert setShowsSuppressionButton:YES];
    [alert addButtonWithTitle:@"OK"];
    [alert beginSheetModalForWindow:[sender window]
                      modalDelegate:self
                     didEndSelector:@selector(applyChangesAlertDidEnd:returnCode:contextInfo:)
                        contextInfo:NULL];
}

- (IBAction) toggleExtAction:(NSButton*)sender {
    NSInteger row = [self.extsTable rowForView:sender];
    MJCacheItem* item = [self.cache objectAtIndex:row];
    item.actionize = ([sender state] == NSOnState);
    [self recacheHasActionsToApply];
}

- (void) toggleExtViaSpacebar {
    NSInteger row = [self.extsTable selectedRow];
    if (row == -1)
        return;
    
    MJCacheItem* item = [self.cache objectAtIndex:row];
    item.actionize = !item.actionize;
    [self.extsTable reloadData];
    [self.extsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [self recacheHasActionsToApply];
}

- (void) tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger row = [self.extsTable selectedRow];
    if (row == -1)
        self.selectedCacheItem = nil;
    else
        self.selectedCacheItem = [self.cache objectAtIndex:row];
}

- (void) recacheHasActionsToApply {
    self.hasActionsToApply = [[self.cache filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"actionize == YES"]] count] > 0;
}

- (BOOL) tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    MJCacheItem* item = [self.cache objectAtIndex:row];
    return item.type != MJCacheItemTypeHeader;
}

- (BOOL) tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row {
    MJCacheItem* item = [self.cache objectAtIndex:row];
    return item.type == MJCacheItemTypeHeader;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex {
    return MAX(proposedMin, 200.0);
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex {
    return MIN(proposedMax, [splitView frame].size.width - 250.0);
}

- (void)splitView:(NSSplitView*)sender resizeSubviewsWithOldSize:(NSSize)oldSize {
    CGFloat w = [[[sender subviews] objectAtIndex:0] frame].size.width;
    [sender adjustSubviews];
    [sender setPosition:w ofDividerAtIndex:0];
}

@end

@interface MJExtensionsTableView : NSTableView
@end

@implementation MJExtensionsTableView

- (void) keyDown:(NSEvent *)theEvent {
    if ([[theEvent characters] isEqualToString: @" "]) {
        MJExtensionsTabController* controller = (id)[self delegate];
        [controller toggleExtViaSpacebar];
    }
    else {
        [super keyDown:theEvent];
    }
}

@end
