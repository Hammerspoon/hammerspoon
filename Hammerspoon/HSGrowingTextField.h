//
//  HSGrowingTextField.h
//  Hammerspoon
//
//  Created by Chris Jones on 11/06/2015.
//  Copyright (c) 2015 Hammerspoon. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface HSGrowingTextField : NSTextField {
    BOOL _hasLastIntrinsicSize;
    BOOL _isEditing;
    NSSize _lastIntrinsicSize;
}

-(void)resetGrowth;
-(NSSize)intrinsicContentSize;

@end
