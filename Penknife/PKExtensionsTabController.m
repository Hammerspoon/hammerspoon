#import "PKExtensionManager.h"
#import "PKExtension.h"

typedef NS_ENUM(NSUInteger, PKCacheItemType) {
    PKCacheItemTypeHeader,
    PKCacheItemTypeNotInstalled,
    PKCacheItemTypeUpToDate,
    PKCacheItemTypeNeedsUpgrade,
    PKCacheItemTypeRemovedRemotely,
};

// oh swift, I do wish you were here already
@interface PKCacheItem : NSObject
@property PKCacheItemType type;
@property PKExtension* ext;
@property NSString* header;
@end
@implementation PKCacheItem
+ (PKCacheItem*) header:(NSString*)title {
    PKCacheItem* item = [[PKCacheItem alloc] init];
    item.type = PKCacheItemTypeHeader;
    item.header = title;
    return item;
}
+ (PKCacheItem*) ext:(PKExtension*)ext type:(PKCacheItemType)type {
    PKCacheItem* item = [[PKCacheItem alloc] init];
    item.type = type;
    item.ext = ext;
    return item;
}
@end

@interface PKExtensionsTabController : NSObject <NSTableViewDataSource, NSTableViewDelegate>
@property (weak) IBOutlet NSTableView* extsTable;
@property NSArray* cache;
@end

@implementation PKExtensionsTabController

- (void) awakeFromNib {
    [self rebuildCache];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(extensionsUpdated:)
                                                 name:PKExtensionsUpdatedNotification
                                               object:nil];
}

- (void) rebuildCache {
    NSMutableArray* cache = [NSMutableArray array];
    
    [cache addObject: [PKCacheItem header: @"Available"]];
    for (PKExtension* ext in [PKExtensionManager sharedManager].extsNotInstalled)
        [cache addObject: [PKCacheItem ext:ext type:PKCacheItemTypeNotInstalled]];
    
    [cache addObject: [PKCacheItem header: @"Installed - Up to Date"]];
    for (PKExtension* ext in [PKExtensionManager sharedManager].extsUpToDate)
        [cache addObject: [PKCacheItem ext:ext type:PKCacheItemTypeUpToDate]];
    
    [cache addObject: [PKCacheItem header: @"Installed - Upgrade Available"]];
    for (PKExtension* ext in [PKExtensionManager sharedManager].extsNeedingUpgrade)
        [cache addObject: [PKCacheItem ext:ext type:PKCacheItemTypeNeedsUpgrade]];
    
    [cache addObject: [PKCacheItem header: @"Installed - No longer offered publicly!"]];
    for (PKExtension* ext in [PKExtensionManager sharedManager].extsRemovedRemotely)
        [cache addObject: [PKCacheItem ext:ext type:PKCacheItemTypeRemovedRemotely]];
    
    self.cache = cache;
}

- (void) extensionsUpdated:(NSNotification*)note {
    [self rebuildCache];
    [self.extsTable reloadData];
}

- (PKExtensionManager*) extManager {
    // for use with binding progress animator
    return [PKExtensionManager sharedManager];
}

- (IBAction) updateExtensions:(id)sender {
    [[PKExtensionManager sharedManager] update];
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
//        [result setBezelStyle:NSTextFieldRoundedBezel];
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

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    PKCacheItem* item = [self.cache objectAtIndex:row];
    
    if (item.type == PKCacheItemTypeHeader) {
        NSTextField* header = [self headerRow:tableView];
        header.stringValue = item.header;
        return header;
    }
    else if ([[tableColumn identifier] isEqualToString: @"name"]) {
        NSTextField* attr = [self attrRow:tableView];
        attr.stringValue = [NSString stringWithFormat:@"%@ %@", item.ext.name, item.ext.version];
        return attr;
    }
    else if ([[tableColumn identifier] isEqualToString: @"author"]) {
        NSTextField* attr = [self attrRow:tableView];
        attr.stringValue = item.ext.author;
        return attr;
    }
    else if ([[tableColumn identifier] isEqualToString: @"website"]) {
        NSTextField* attr = [self attrRow:tableView];
        attr.stringValue = item.ext.website;
        return attr;
    }
    else if ([[tableColumn identifier] isEqualToString: @"license"]) {
        NSTextField* attr = [self attrRow:tableView];
        attr.stringValue = item.ext.license;
        return attr;
    }
    else if ([[tableColumn identifier] isEqualToString: @"desc"]) {
        NSTextField* attr = [self attrRow:tableView];
        attr.stringValue = item.ext.desc;
        return attr;
    }
    else if ([[tableColumn identifier] isEqualToString: @"action"]) {
        NSString* title;
        switch (item.type) {
            case PKCacheItemTypeNeedsUpgrade:    title = @"Upgrade"; break;
            case PKCacheItemTypeNotInstalled:    title = @"Install"; break;
            case PKCacheItemTypeRemovedRemotely: title = @"Uninstall"; break;
            case PKCacheItemTypeUpToDate:        title = @"Uninstall"; break;
            default: break;
        }
        NSButton* action = [self actionRow:tableView];
        action.title = title;
        action.state = NSOffState;
        return action;
    }
    
    return nil; // unreachable (I hope)
}

- (IBAction) toggleExtAction:(id)sender {
    NSInteger row = [self.extsTable clickedRow];
    NSLog(@"%ld", row);
    
//    row = 0;
//    PKExtension* ext = [[PKExtensionManager sharedManager].cache.extensionsAvailable objectAtIndex:row];
//    
//    NSLog(@"%@", ext);
}

- (BOOL) tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    PKCacheItem* item = [self.cache objectAtIndex:row];
    return item.type != PKCacheItemTypeHeader;
}

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row {
    PKCacheItem* item = [self.cache objectAtIndex:row];
    return item.type == PKCacheItemTypeHeader;
}

@end
