//
//  internal.m
//  Hammerspoon
//
//  Created by Chris Jones on 28/10/2021.
//  Copyright © 2021 Hammerspoon. All rights reserved.
//

@import Cocoa;
@import LuaSkin;

#import "ShortcutsEvents.h"

static LSRefTable  refTable = LUA_NOREF ;

/// hs.shortcuts.list() -> []
/// Function
/// Returns a list of available shortcuts
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table of shortcuts, each being a table with the following keys:
///   * name - The name of the shortcut
///   * id - A unique ID for the shortcut
///   * acceptsInput - A boolean indicating if the shortcut requires input
///   * actionCount - A number relating to how many actions are in the shortcut
static int shortcuts_list(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    ShortcutsEventsApplication *app = [SBApplication applicationWithBundleIdentifier:@"com.apple.shortcuts.events"];

    NSMutableArray *shortcuts = [[NSMutableArray alloc] init];
    for (ShortcutsEventsShortcut *shortcut in app.shortcuts) {
        NSDictionary *data = @{@"name": shortcut.name,
                                   @"id": shortcut.id,
                                   @"acceptsInput": [NSNumber numberWithBool:shortcut.acceptsInput],
                                   @"actionCount": [NSNumber numberWithLong:shortcut.actionCount]

        };
        [shortcuts addObject:data];
    }

    [skin pushNSObject:shortcuts];
    return 1;
}

/// hs.shortcuts.run(name)
/// Function
/// Execute a Shortcuts shortcut by name
///
/// Parameters:
///  * name - A string containing the name of the Shortcut to execute
///
/// Returns:
///  * None
static int shortcuts_run(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];

    NSString *name = [skin toNSObjectAtIndex:1];

    ShortcutsEventsApplication *app = [SBApplication applicationWithBundleIdentifier:@"com.apple.shortcuts.events"];
    for (ShortcutsEventsShortcut *shortcut in app.shortcuts) {
        if ([shortcut.name isEqual:name]) {
            [shortcut runWithInput:nil];
            break;
        }
    }

    return 0;
}

static luaL_Reg moduleLib[] = {
    {"list", shortcuts_list},
    {"run", shortcuts_run},
    {NULL, NULL}
};

int luaopen_hs_libshortcuts(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibrary:"hs.shortcuts" functions:moduleLib metaFunctions:nil];
    return 1;
}
