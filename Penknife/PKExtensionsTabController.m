#import "PKExtensionManager.h"
#import "PKExtension.h"

@interface PKExtensionsTabController : NSObject <NSTableViewDataSource, NSTableViewDelegate>
@property (weak) IBOutlet NSTableView* extsTable;
@end

@implementation PKExtensionsTabController

- (void) awakeFromNib {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(extensionsUpdated:) name:PKExtensionsUpdatedNotification object:nil];
}

- (void) extensionsUpdated:(NSNotification*)note {
    [self.extsTable reloadData];
}

- (PKExtensionManager*) extManager { // for use with binding progress animator
    return [PKExtensionManager sharedManager];
}

- (IBAction) updateExtensions:(id)sender {
    [[PKExtensionManager sharedManager] update];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [[PKExtensionManager sharedManager].cache.extensionsAvailable count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    PKExtension* ext = [[PKExtensionManager sharedManager].cache.extensionsAvailable objectAtIndex:row];
    
    if ([[tableColumn identifier] isEqualToString: @"name"]) {
        return ext.name;
    }
    else if ([[tableColumn identifier] isEqualToString: @"installed"]) {
        return @NO;
    }
    else if ([[tableColumn identifier] isEqualToString: @"version"]) {
        return ext.version;
    }
    else if ([[tableColumn identifier] isEqualToString: @"action"]) {
        return @"";
    }
    
    return nil;
}

- (IBAction) toggleInstalled:(id)sender {
    NSInteger row = [self.extsTable clickedRow];
    PKExtension* ext = [[PKExtensionManager sharedManager].cache.extensionsAvailable objectAtIndex:row];
    
    NSLog(@"%@", ext);
}

@end
