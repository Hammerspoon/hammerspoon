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
    NSLog(@"%@", self.cache);
    return 37;
//    return [self.cache count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
//    row = 0;
//    PKExtension* ext = [[PKExtensionManager sharedManager].cache.extensionsAvailable objectAtIndex:row];
    
//    if ([[tableColumn identifier] isEqualToString: @"name"]) {
//        return ext.name;
//    }
//    else if ([[tableColumn identifier] isEqualToString: @"installed"]) {
//        return @NO;
//    }
//    else if ([[tableColumn identifier] isEqualToString: @"version"]) {
//        return ext.version;
//    }
//    else if ([[tableColumn identifier] isEqualToString: @"action"]) {
//        return @"";
//    }
    
    if (row == 0 || row == 3) {
        NSLog(@"%@", [tableColumn identifier]);
        NSTextField *result = [tableView makeViewWithIdentifier:@"header" owner:self];
        if (result == nil) {
            result = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 100, 0)];
            [result setBordered:NO];
            [result setBezelStyle:NSTextFieldRoundedBezel];
            [result setEditable:NO];
            result.identifier = @"header";
        }
        result.stringValue = @"Installed";
        return result;
    }
    
    NSButton* button = [tableView makeViewWithIdentifier:@"button" owner:self];
    if (!button) {
        button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 100, 0)];
        [button setAllowsMixedState:YES];
        [button setButtonType:NSSwitchButton];
        [button setTitle:@""];
        button.identifier = @"button";
    }
    [button setState:NSMixedState];
    
    return button;
}

- (IBAction) toggleInstalled:(id)sender {
//    NSInteger row = [self.extsTable clickedRow];
//    row = 0;
//    PKExtension* ext = [[PKExtensionManager sharedManager].cache.extensionsAvailable objectAtIndex:row];
//    
//    NSLog(@"%@", ext);
}

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row {
    return row == 3 || row == 0;
}

@end
