//
//  HSChooserTableView.h
//  Hammerspoon
//
//  Created by Chris Jones on 30/12/2015.
//  Copyright © 2015 Hammerspoon. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// Here we're defining an extra protocol for our own methods, to avoid overloading the normal NSTableViewDelegate

@protocol HSChooserTableViewDelegate <NSObject>

- (void)tableView:(NSTableView *)tableView didClickedRow:(NSInteger)row;

@end

@interface HSChooserTableView : NSTableView

@property (nonatomic, weak) id<HSChooserTableViewDelegate> extendedDelegate;

@end
