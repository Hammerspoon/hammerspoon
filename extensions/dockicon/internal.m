#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>


extern BOOL MJDockIconVisible(void) ;
extern void MJDockIconSetVisible(BOOL visible) ;

/// hs.dockicon.visible() -> bool
/// Function
/// Determine whether Hammerspoon's dock icon is visible
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if the dock icon is visible, false if not
static int icon_visible(lua_State* L) {
    BOOL indock = MJDockIconVisible();
    lua_pushboolean(L, indock);
    return 1;
}

/// hs.dockicon.show()
/// Function
/// Make Hammerspoon's dock icon visible
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int icon_show(lua_State* L __unused) {
    MJDockIconSetVisible(YES) ;
    return 0;
}

/// hs.dockicon.hide()
/// Function
/// Hide Hammerspoon's dock icon
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int icon_hide(lua_State* L __unused) {
    MJDockIconSetVisible(NO) ;
    return 0;
}

/// hs.dockicon.bounce(indefinitely)
/// Function
/// Bounce Hammerspoon's dock icon
///
/// Parameters:
///  * indefinitely - A boolean value, true if the dock icon should bounce until the dock icon is clicked, false if the dock icon should only bounce briefly
static int icon_bounce(lua_State* L) {
    [[NSApplication sharedApplication] requestUserAttention: lua_toboolean(L, 1) ? NSCriticalRequest : NSInformationalRequest];
    return 0;
}

/// hs.dockicon.setBadge(badge)
/// Function
/// Set Hammerspoon's dock icon badge
///
/// Parameters:
///  * badge - A string containing the label to place inside the dock icon badge. If the string is empty, the badge will be cleared
static int icon_setBadge(lua_State* L) {
    NSDockTile* tile = [[NSApplication sharedApplication] dockTile];
    [tile setBadgeLabel:[NSString stringWithUTF8String: luaL_checkstring(L, 1)]];
    [tile display];
    return 0;
}

static luaL_Reg icon_lib[] = {
    {"visible", icon_visible},
    {"show", icon_show},
    {"hide", icon_hide},
    {"bounce", icon_bounce},
    {"setBadge", icon_setBadge},
    {NULL, NULL}
};

int luaopen_hs_dockicon_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibrary:icon_lib metaFunctions:nil];

    return 1;
}
