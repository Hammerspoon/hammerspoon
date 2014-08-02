#import "PKExtManager.h"

@interface PKExtensionsController : NSObject <NSTableViewDataSource, NSTableViewDelegate>
@property (weak) IBOutlet NSTableView* extsTable;
@end

@implementation PKExtensionsController

- (void) awakeFromNib {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(extensionsUpdated:) name:PKExtensionsUpdatedNotification object:nil];
}

- (void) extensionsUpdated:(NSNotification*)note {
    NSLog(@"ok");
}

//- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
////    return [[[PKExtManager sharedExtManager] availableExts] count];
//}

//- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
////    NSDictionary* item = [[[PKExtManager sharedExtManager] availableExts] objectAtIndex:row];
////    
////    if ([[tableColumn identifier] isEqualToString: @"name"]) {
////        
////    }
////    else if ([[tableColumn identifier] isEqualToString: @"installed"]) {
////        
////    }
////    else if ([[tableColumn identifier] isEqualToString: @"version"]) {
////        
////    }
////    else if ([[tableColumn identifier] isEqualToString: @"action"]) {
////        
////    }
////    
////    return [item objectForKey: @"path"];
//}

@end
