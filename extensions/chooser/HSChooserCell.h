//
//  HSChooserCell.h
//  Hammerspoon
//
//  Created by Chris Jones on 29/12/2015.
//  Copyright © 2015 Hammerspoon. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface HSChooserCell : NSTableCellView

@property (unsafe_unretained) IBOutlet NSTextField *text;
@property (unsafe_unretained) IBOutlet NSTextField *subText;
@property (unsafe_unretained) IBOutlet NSTextField *shortcutText;
@property (unsafe_unretained) IBOutlet NSImageView *image;

@end
