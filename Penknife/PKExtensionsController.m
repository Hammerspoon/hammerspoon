#import "PKExtensionManager.h"
#import "PKExtension.h"

@interface PKExtensionsController : NSObject <NSTableViewDataSource, NSTableViewDelegate>
@property (weak) IBOutlet NSTableView* extsTable;
@end

@implementation PKExtensionsController

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
    return [[PKExtensionManager sharedManager].cache.extensions count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    PKExtension* ext = [[PKExtensionManager sharedManager].cache.extensions objectAtIndex:row];
    
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

@end
