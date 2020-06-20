//
//  internal.m
//  Hammerspoon
//
//  Created by Linghua Zhang on 2018/03/15.
//  Copyright © 2018 Hammerspoon. All rights reserved.
//

@import Foundation;
@import Cocoa;
#import <LuaSkin/LuaSkin.h>

#pragma mark - Module Functions

// key, value, app id
static int userpreferences_set(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TSTRING|LS_TNUMBER|LS_TBOOLEAN|LS_TINTEGER|LS_TNIL, LS_TSTRING, LS_TBREAK];

    NSString *key = [skin toNSObjectAtIndex:1];
    id value = [skin toNSObjectAtIndex:2];
    NSString *applicationId  = [skin toNSObjectAtIndex:3];

    CFPreferencesSetValue((__bridge CFStringRef) key,
                          (__bridge CFPropertyListRef) value,
                          (__bridge CFStringRef) applicationId,
                          kCFPreferencesCurrentUser,
                          kCFPreferencesCurrentHost);
    return 0;
}

static int userpreferences_get(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TBREAK];

    NSString *key = [skin toNSObjectAtIndex:1];
    NSString *applicationId = [skin toNSObjectAtIndex:2];

    CFPropertyListRef ref = CFPreferencesCopyValue((__bridge CFStringRef)key,
                                                   (__bridge CFStringRef)applicationId,
                                                   kCFPreferencesCurrentUser,
                                                   kCFPreferencesCurrentHost);
    if (ref != nil) {
        [skin pushNSObject:(__bridge_transfer NSObject *)ref];
    } else {
        [skin pushNSObject:[NSNull null]];
    }

    return 1;
}

static int userpreferences_sync(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];

    NSString *applicationId = [skin toNSObjectAtIndex:1];
    CFPreferencesSynchronize((__bridge CFStringRef)applicationId,
                             kCFPreferencesCurrentUser,
                             kCFPreferencesCurrentHost);
    return 0;
}

static const luaL_Reg userpreferencesLib[] = {
    {"set", userpreferences_set},
    {"get", userpreferences_get},
    {"sync", userpreferences_sync},

    {NULL, NULL}
};

int luaopen_hs_userpreferences_internal(__unused lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin registerLibrary:userpreferencesLib metaFunctions:nil];

    return 1;
}
