#import <Cocoa/Cocoa.h>
#import <lauxlib.h>

// Check out NSScriptClassDescription for expanding obj return values...

static int runapplescript(lua_State* L) {
    NSString* source = [NSString stringWithUTF8String:luaL_checkstring(L, 1)];

    NSAppleScript* script = [[NSAppleScript alloc] initWithSource:source];
    NSDictionary *__autoreleasing error;
    NSAppleEventDescriptor* result = [script executeAndReturnError:&error];

    lua_pushboolean(L, (result != nil));
    if (result == nil)
//         mjolnir_push_luavalue_for_nsobject(L, (NSArray *)error); // I don't think this ever worked, but it is what was in Hydra
        lua_pushstring(L, [[NSString stringWithFormat:@"%@", error] UTF8String]);
    else {
//         lua_pushstring(L, [[result stringValue] UTF8String]); // worked only for string results...
        lua_pushstring(L, [[NSString stringWithFormat:@"%@", result] UTF8String]); // ugly, but parseable in Lua, sorta...
//         mjolnir_push_luavalue_for_nsobject(L, arrayFromDescriptor(result)); // my pipe dream, but not yet...
    }
    return 2;
}

static const luaL_Reg scriptlib[] = {
    {"_applescript", runapplescript},
    {NULL, NULL}
};

int luaopen_hs_applescript_internal(lua_State* L) {
    luaL_newlib(L, scriptlib);

    return 1;
}

// // Still chokes on "index a binary value" for NSError as NSDictionary... gonna have to dig.
// // plus, I don't like the examples in Hydra... one treats a NSDictionary of 1 element as a
// // boolean (settings... since it's plists, it might be right, need to check) and another
// // treats a NSNumber of 1 or 0 as boolean, all others as NSNumber... probably because C does,
// // but it's a bad default for a general function...
//
// void mjolnir_push_luavalue_for_nsobject(lua_State* L, id obj) {
//     if (obj == nil) {
//         // not set yet
//         lua_pushnil(L);
//     }
//     else if ([obj isKindOfClass: [NSDictionary class]]) {
//         NSDictionary* thing = obj;
//         lua_newtable(L);
//         for (id key in thing) {
//             mjolnir_push_luavalue_for_nsobject(L, key);
//             mjolnir_push_luavalue_for_nsobject(L, [thing objectForKey:key]);
//             lua_settable(L, -3);
//         }
//     }
//     else if ([obj isKindOfClass: [NSNumber class]]) {
//         if (obj == (id)kCFBooleanTrue)
//             lua_pushboolean(L, YES);
//         else if (obj == (id)kCFBooleanFalse)
//             lua_pushboolean(L, NO);
//         else
//             lua_pushnumber(L, [(NSNumber*)obj doubleValue]);
//     }
// //     else if ([obj isKindOfClass: [NSNumber class]]) {
// //         NSNumber* number = obj;
// //         lua_pushnumber(L, [number doubleValue]);
// //     }
//     else if ([obj isKindOfClass: [NSString class]]) {
//         NSString* string = obj;
//         lua_pushstring(L, [string UTF8String]);
//     }
//     else if ([obj isKindOfClass: [NSArray class]]) {
//         NSArray* list = obj;
//         lua_newtable(L);
//
//         for (int i = 0; i < [list count]; i += 2) {
//             id key = [list objectAtIndex:i];
//             id val = [list objectAtIndex:i + 1];
//             mjolnir_push_luavalue_for_nsobject(L, key);
//             mjolnir_push_luavalue_for_nsobject(L, val);
//             lua_settable(L, -3);
//         }
//     }
// }

// // Almost, but I need to understand NSAppleEventDescriptor better...
// id arrayFromDescriptor(NSAppleEventDescriptor *descriptor) {
//     NSMutableArray *returnArray = [NSMutableArray array];
//     int counter, count = [descriptor numberOfItems];
//
//     for (counter = 1; counter <= count; counter++) {
//         NSAppleEventDescriptor *desc = [descriptor descriptorAtIndex:counter];
//         if (nil != [desc descriptorAtIndex:1]) {
//             [returnArray addObject:arrayFromDescriptor(desc)];
//         } else {
//             NSString *stringValue = [[descriptor descriptorAtIndex:counter] stringValue];
//             if (nil != stringValue) {
//                 [returnArray addObject:stringValue];
//             } else {
//                 NSString *holder = [NSString stringWithFormat:@"%@", desc];
//                 [returnArray addObject:holder];
//             }
//         }
//     }
//     return returnArray;
// }
