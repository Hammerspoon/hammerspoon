//
//  HSGrowingTextField.m
//  Hammerspoon
//
//  Created by Chris Jones on 11/06/2015.
//  Copyright (c) 2015 Hammerspoon. All rights reserved.
//

#import "HSGrowingTextField.h"

@implementation HSGrowingTextField

- (void)textDidBeginEditing:(NSNotification *)notification {
    [super textDidBeginEditing:notification];
    _isEditing = YES;
}

- (void)textDidEndEditing:(NSNotification *)notification {
    [super textDidEndEditing:notification];
    _isEditing = NO;
}

- (void)textDidChange:(NSNotification *)notification {
    [super textDidChange:notification];
    [self invalidateIntrinsicContentSize];
}

- (void)resetGrowth {
    _hasLastIntrinsicSize = NO;
    [self invalidateIntrinsicContentSize];
}

-(NSSize)intrinsicContentSize {
    NSSize intrinsicSize = _lastIntrinsicSize;

    // Only update the size if we’re editing the text, or if we’ve not set it yet
    // If we try and update it while another text field is selected, it may shrink back down to only the size of one line (for some reason?)
    if(_isEditing || !_hasLastIntrinsicSize) {
        intrinsicSize = [super intrinsicContentSize];

        // If we’re being edited, get the shared NSTextView field editor, so we can get more info
        NSText *fieldEditor = [self.window fieldEditor:NO forObject:self];
        if([fieldEditor isKindOfClass:[NSTextView class]]) {
            NSTextView *textView = (NSTextView *)fieldEditor;
            [textView.textContainer.layoutManager ensureLayoutForTextContainer:textView.textContainer] ;
            NSRect usedRect = [textView.textContainer.layoutManager usedRectForTextContainer:textView.textContainer];

            usedRect.size.height += 5.0; // magic number! (the field editor TextView is offset within the NSTextField. It’s easy to get the space above (it’s origin), but it’s difficult to get the default spacing for the bottom, as we may be changing the height

            intrinsicSize.height = usedRect.size.height;
        }

        if (intrinsicSize.height > 100) {
            intrinsicSize.height = 100;
        } else {
            _lastIntrinsicSize = intrinsicSize;
            _hasLastIntrinsicSize = YES;
        }
    }

    return intrinsicSize;
}

@end
