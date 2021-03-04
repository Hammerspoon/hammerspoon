@import Cocoa ;
@import LuaSkin ;

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

@interface NSView (HSCanvasView)
-(NSWindow *)wrapperWindow ;
@end
/// hs.dockicon.tileCanvas([canvas]) -> canvasObject | nil
/// Function
/// Get or set a canvas object to be displayed as the Hamemrspoon dock icon
///
/// Parameters:
///  * `canvas` - an optional `hs.canvas` object specifying the canvas to be displayed as the dock icon for Hammerspoon. If an explicit `nil` is specified, the dock icon will revert to the Hammerspoon application icon.
///
/// Returns:
///  * If the dock icon is assigned a canvas object, that canvas object will be returned, otherwise returns nil.
///
/// Notes:
///  * If you update the canvas object by changing any of its components, it will not be reflected in the dock icon until you invoke [hs.dockicon.tileUpdate](#tileUpdate).
static int icon_docktileCanvas(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    NSDockTile *tile = [[NSApplication sharedApplication] dockTile];

    if (lua_gettop(L) != 0) {
        NSView *oldView = tile.contentView ;
        if (lua_type(L, 1) == LUA_TNIL) {
            tile.contentView = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, "hs.canvas", LS_TBREAK] ;
            tile.contentView = [skin toNSObjectAtIndex:1] ;
        }
        [tile display] ;
        // if canvas removed from tile, reattach it so it can be displayed as a canvas again
        if (![oldView isEqualTo:tile.contentView] && [oldView isKindOfClass:NSClassFromString(@"HSCanvasView")]) {
            [oldView.wrapperWindow setContentView:oldView] ;
        }
    }
    [skin pushNSObject:tile.contentView] ;
    return 1 ;
}

/// hs.dockicon.tileSize() -> size table
/// Function
/// Returns a table containing the size of the tile representing the dock icon.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing the size of the tile representing the dock icon for Hammerspoon. This table will contain `h` and `w` keys specifying the tile height and width as numbers.
///
/// Notes:
///  * the size returned specifies the display size of the dock icon tile. If your canvas item is larger than this, then only the top left portion corresponding to the size returned will be displayed.
static int icon_docktileSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    NSDockTile *tile = [[NSApplication sharedApplication] dockTile];

    [skin pushNSSize:tile.size] ;
    return 1 ;
}

/// hs.dockicon.tileUpdate() -> none
/// Function
/// Force an update of the dock icon.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * Changes made to a canvas object are not reflected automatically like they are when a canvas is being displayed on the screen; you must invoke this method after making changes to the canvas for the updates to be reflected in the dock icon.
static int icon_docktileUpdate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    NSDockTile *tile = [[NSApplication sharedApplication] dockTile];

    [tile display] ;
    return 0 ;
}

static luaL_Reg icon_lib[] = {
    {"visible", icon_visible},
    {"show", icon_show},
    {"hide", icon_hide},
    {"bounce", icon_bounce},
    {"setBadge", icon_setBadge},
    {"tileCanvas", icon_docktileCanvas},
    {"tileSize", icon_docktileSize},
    {"tileUpdate", icon_docktileUpdate},
    {NULL, NULL}
};

int luaopen_hs_dockicon_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibrary:"hs.dockicon" functions:icon_lib metaFunctions:nil];

    return 1;
}
