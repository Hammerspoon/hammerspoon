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

int luaopen_hs_shortcuts_internal(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibrary:"hs.shortcuts" functions:moduleLib metaFunctions:nil];
    return 1;
}
