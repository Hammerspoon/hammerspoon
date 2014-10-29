#import <Cocoa/Cocoa.h>
#import <lauxlib.h>


extern BOOL MJDockIconVisible(void) ;
extern void MJDockIconSetVisible(BOOL visible) ;

/// hs.dockicon.visible() -> bool
/// Function
/// Returns whether Mjolnir has a Dock icon, and thus can be switched to via Cmd-Tab.
static int icon_visible(lua_State* L) {
    BOOL indock = MJDockIconVisible();
    lua_pushboolean(L, indock);
    return 1;
}

/// hs.dockicon.show()
/// Function
/// Shows Mjolnir's dock icon; Mjolnir can then be switched to via Cmd-Tab.
static int icon_show(lua_State* L __unused) {
    MJDockIconSetVisible(YES) ;
    return 0;
}

/// hs.dockicon.hide()
/// Function
/// Hides Mjolnir's dock icon; Mjolnir will no longer show up when you Cmd-Tab.
static int icon_hide(lua_State* L __unused) {
    MJDockIconSetVisible(NO) ;
    return 0;
}

/// hs.dockicon.bounce(indefinitely = false)
/// Function
/// Bounces Mjolnir's dock icon; if indefinitely is true, won't stop until you click the dock icon.
static int icon_bounce(lua_State* L) {
    [[NSApplication sharedApplication] requestUserAttention: lua_toboolean(L, 1) ? NSCriticalRequest : NSInformationalRequest];
    return 0;
}

/// hs.dockicon.setbadge(str)
/// Function
/// Set's Mjolnir's dock icon's badge to the given string; pass an empty string to clear it.
static int icon_setbadge(lua_State* L) {
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
    {"setbadge", icon_setbadge},
    {NULL, NULL}
};

int luaopen_hs_dockicon_internal(lua_State* L) {
    luaL_newlib(L, icon_lib);
    return 1;
}
