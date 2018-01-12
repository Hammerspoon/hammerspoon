#import <Foundation/Foundation.h>
#import <LuaSkin/LuaSkin.h>
#import "../application/application.h"

@interface HSwindow : NSObject
@property (nonatomic, readonly) pid_t pid;
@property (nonatomic, readonly) AXUIElementRef elementRef;
@property (nonatomic, readonly) CGWindowID winID;
@property (nonatomic) int selfRefCount;

@property (nonatomic, readonly, getter=title) NSString *title;
@property (nonatomic, readonly, getter=role) NSString *role;
@property (nonatomic, readonly, getter=subRole) NSString *subRole;
@property (nonatomic, readonly, getter=isStandard) BOOL isStandard;
@property (nonatomic, getter=getTopLeft, setter=setTopLeft:) NSPoint topLeft;
@property (nonatomic, getter=getSize, setter=setSize:) NSSize size;
@property (nonatomic, getter=isFullscreen, setter=setFullscreen:) BOOL fullscreen;
@property (nonatomic, getter=isMinimized, setter=setMinimized:) BOOL minimized;
@property (nonatomic, getter=getApplication) id application;
@property (nonatomic, readonly, getter=getZoomButtonRect) NSRect zoomButtonRect;
@property (nonatomic, readonly, getter=getTabCount) int tabCount;

// Class methods
+(NSArray<NSNumber *>*)orderedWindowIDs;
+(NSImage *)snapshotForID:(int)windowID keepTransparency:(BOOL)keepTransparency;
+(HSwindow *)focusedWindow;

// Initialiser
-(HSwindow *)initWithAXUIElementRef:(AXUIElementRef)winRef;

// Destructor
-(void)dealloc;

// Instance methods
-(NSString *)title;
-(NSString *)subRole;
-(NSString *)role;
-(BOOL)isStandard;
-(NSPoint)getTopLeft;
-(void)setTopLeft:(NSPoint)topLeft;
-(NSSize)getSize;
-(void)setSize:(NSSize)size;
-(BOOL)pushButton:(CFStringRef)buttonId;
-(void)toggleZoom;
-(NSRect)getZoomButtonRect;
-(BOOL)close;
-(BOOL)focusTab:(int)index;
-(int)getTabCount;
-(BOOL)isFullscreen;
-(void)setFullscreen:(BOOL)fullscreen;
-(BOOL)isMinimized;
-(void)setMinimized:(BOOL)minimize;
-(id)getApplication;
-(void)becomeMain;
-(void)raise;
-(NSImage *)snapshot:(BOOL)keepTransparency;
@end

extern AXError _AXUIElementGetWindow(AXUIElementRef, CGWindowID* out);
