#import <Foundation/Foundation.h>
#import <LuaSkin/LuaSkin.h>
#import "../application/application.h"

@interface HSwindow : NSObject
@property (nonatomic, readonly) pid_t pid;
@property (nonatomic, readonly) AXUIElementRef winRef;
@property (nonatomic, readonly) CGWindowID winID;
@property (nonatomic) int selfRef;

@property (nonatomic, readonly, getter=title) NSString *title;
@property (nonatomic, readonly, getter=role) NSString *role;
@property (nonatomic, readonly, getter=subRole) NSString *subRole;
@property (nonatomic, readonly, getter=isStandard) BOOL isStandard;
@property (nonatomic, getter=getTopLeft, setter=setTopLeft:) CGPoint topLeft;
@property (nonatomic, getter=getSize, setter=setSize:) CGSize size;
@property (nonatomic, getter=isFullscreen, setter=setFullscreen:) BOOL fullscreen;
@property (nonatomic, getter=isMinimized, setter=setMinimized:) BOOL minimized;
@property (nonatomic, getter=getApplication) id application;

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
-(CGPoint)getTopLeft;
-(void)setTopLeft:(CGPoint)topLeft;
-(CGSize)getSize;
-(void)setSize:(CGSize)size;
-(BOOL)pushButton:(CFStringRef)buttonId;
-(void)toggleZoom;
-(CGRect)zoomButtonRect;
-(void)close;
-(BOOL)focusTab:(int)index;
-(int)tabCount;
-(BOOL)isFullscreen;
-(void)setFullscreen:(BOOL)fullscreen;
-(BOOL)isMinimized;
-(void)setMinimized:(BOOL)minimize;
-(id)getApplication;
-(void)becomeMain;
-(void)raise;
-(NSImage *)snapshot;
@end

extern AXError _AXUIElementGetWindow(AXUIElementRef, CGWindowID* out);

// FIXME: This needs to be removed.
static void new_window(lua_State* L, AXUIElementRef win) {
    AXUIElementRef* winptr = lua_newuserdata(L, sizeof(AXUIElementRef));
    *winptr = win;

    luaL_getmetatable(L, "hs.window");
    lua_setmetatable(L, -2);

    lua_newtable(L);

    pid_t pid;
    if (AXUIElementGetPid(win, &pid) == kAXErrorSuccess) {
        lua_pushinteger(L, pid);
        lua_setfield(L, -2, "pid");
    }

    CGWindowID winid;
    AXError err = _AXUIElementGetWindow(win, &winid);
    if (!err) {
        lua_pushinteger(L, winid);
        lua_setfield(L, -2, "id");
    }

    lua_setuservalue(L, -2);
}
