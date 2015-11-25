#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

// Declare our Lua userdata object and a storage container for them
typedef struct _drawing_t {
    void *window;
// hs.drawing objects created outside of this module might have reason to avoid the
// auto-close of this modules __gc
    BOOL skipClose ;
} drawing_t;

// Objective-C class interface definitions
@interface HSDrawingWindow : NSPanel <NSWindowDelegate>
@end

@interface HSDrawingView : NSView {
    lua_State *L;
}
@property int mouseUpCallbackRef;
@property int mouseDownCallbackRef;
@property BOOL HSFill;
@property BOOL HSStroke;
@property CGFloat HSLineWidth;
@property (nonatomic, strong) NSColor *HSFillColor;
@property (nonatomic, strong) NSColor *HSGradientStartColor;
@property (nonatomic, strong) NSColor *HSGradientEndColor;
@property int HSGradientAngle;
@property (nonatomic, strong) NSColor *HSStrokeColor;
@property CGFloat HSRoundedRectXRadius;
@property CGFloat HSRoundedRectYRadius;
@end

@interface HSDrawingViewCircle : HSDrawingView
@end

@interface HSDrawingViewArc : HSDrawingView
@property NSPoint center;
@property CGFloat radius;
@property CGFloat startAngle;
@property CGFloat endAngle;
@end

@interface HSDrawingViewRect : HSDrawingView
@end

@interface HSDrawingViewLine : HSDrawingView
@property NSPoint origin;
@property NSPoint end;
@end

@interface HSDrawingViewText : HSDrawingView
@property (nonatomic, strong) NSTextField *textField;
@end

@interface HSDrawingViewImage : HSDrawingView
@property (nonatomic, strong) NSImageView *HSImageView;
@property (nonatomic, strong) NSImage *HSImage;
@end

