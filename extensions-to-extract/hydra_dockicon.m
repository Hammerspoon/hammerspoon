#import "helpers.h"

/// === hydra.dockicon ===
///
/// Functions for controlling Hydra's own dock icon.

/// hydra.dockicon.visible() -> bool
/// Returns whether Hydra has a Dock icon, and thus can be switched to via Cmd-Tab.
static int dockicon_visible(lua_State* L) {
    BOOL indock = [[NSApplication sharedApplication] activationPolicy] == NSApplicationActivationPolicyRegular;
    lua_pushboolean(L, indock);
    return 1;
}

/// hydra.dockicon.show()
/// Shows Hydra's dock icon; Hydra can then be switched to via Cmd-Tab.
static int dockicon_show(lua_State* L) {
    [[NSApplication sharedApplication] setActivationPolicy: NSApplicationActivationPolicyRegular];
    return 0;
}

/// hydra.dockicon.hide()
/// Hides Hydra's dock icon; Hydra will no longer show up when you Cmd-Tab.
static int dockicon_hide(lua_State* L) {
    [[NSApplication sharedApplication] setActivationPolicy: NSApplicationActivationPolicyAccessory];
    return 0;
}

/// hydra.dockicon.bounce(indefinitely = false)
/// Bounces Hydra's dock icon; if indefinitely is true, won't stop until you click the dock icon.
static int dockicon_bounce(lua_State* L) {
    [[NSApplication sharedApplication] requestUserAttention: lua_toboolean(L, 1) ? NSCriticalRequest : NSInformationalRequest];
    return 0;
}

/// hydra.dockicon.setbadge(str)
/// Set's Hydra's dock icon's badge to the given string; pass an empty string to clear it.
static int dockicon_setbadge(lua_State* L) {
    NSDockTile* tile = [[NSApplication sharedApplication] dockTile];
    [tile setBadgeLabel:[NSString stringWithUTF8String: luaL_checkstring(L, 1)]];
    [tile display];
    return 0;
}

static luaL_Reg dockiconlib[] = {
    {"visible", dockicon_visible},
    {"show", dockicon_show},
    {"hide", dockicon_hide},
    {"bounce", dockicon_bounce},
    {"setbadge", dockicon_setbadge},
    {NULL, NULL}
};

int luaopen_hydra_dockicon(lua_State* L) {
    luaL_newlib(L, dockiconlib);
    return 1;
}
