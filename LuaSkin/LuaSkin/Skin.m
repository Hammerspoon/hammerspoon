//
//  Skin.m
//  LuaSkin
//
//  Created by Chris Jones on 11/06/2015.
//  Copyright (c) 2015 Hammerspoon Project Authors. All rights reserved.
//

#import "Skin.h"

@implementation LuaSkin

#pragma mark - Skin Properties

@synthesize L = _L;

NSMutableDictionary *registeredNSHelperFunctions ;

#pragma mark - Class lifecycle

+ (id)shared {
    static LuaSkin *sharedLuaSkin = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedLuaSkin = [[self alloc] init];
        registeredNSHelperFunctions = [[NSMutableDictionary alloc] init] ;
    });
    if (![NSThread isMainThread]) {
        NSLog(@"GRAVE BUG: LUA EXECUTION ON NON-MAIN THREAD");
        abort();
    }
    return sharedLuaSkin;
}

- (id)init {
    self = [super init];
    if (self) {
        _L = NULL;
        [self createLuaState];
    }
    return self;
}

#pragma mark - lua_State lifecycle

- (void)createLuaState {
    NSLog(@"createLuaState");
    NSAssert((_L == NULL), @"createLuaState called on a live Lua environment", nil);
    _L = luaL_newstate();
    luaL_openlibs(_L);
}

- (void)destroyLuaState {
    NSLog(@"destroyLuaState");
    NSAssert((_L != NULL), @"destroyLuaState called with no Lua environment", nil);
    if (_L) {
        lua_close(_L);
    }
    _L = NULL;
}

- (void)resetLuaState {
    NSLog(@"resetLuaState");
    NSAssert((_L != NULL), @"resetLuaState called with no Lua environment", nil);
    [self destroyLuaState];
    [self createLuaState];
}

#pragma mark - Methods for calling into Lua from C

- (BOOL)protectedCallAndTraceback:(int)nargs nresults:(int)nresults {
    // At this point we are being called with nargs+1 items on the stack, but we need to shove our traceback handler below that

    // Get debug.traceback() onto the top of the stack
    lua_getglobal(_L, "debug");
    lua_getfield(_L, -1, "traceback");
    lua_remove(_L, -2);

    // Move debug.traceback() to the bottom of the stack.
    // The stack currently looks like this, for nargs == 3:
    //  -1 debug.traceback()
    //  -2 argN
    //  -3 argN - 1
    //  -4 argN - 2
    //  -5 function
    //
    // The stack should look like this, for nargs == 3:
    //  -1 argN
    //  -2 argN - 1
    //  -3 argN - 2
    //  -4 function
    //  -5 debug.traceback()
    //
    // Or, for nargs == 0:
    //  -1 function
    //  -2 debug.traceback()
    int tracebackPosition = -nargs - 2;
    lua_insert(_L, tracebackPosition);

    if (lua_pcall(_L, nargs, nresults, tracebackPosition) != LUA_OK) {
        return NO;
    }

    return YES;
}

#pragma mark - Methods for registering libraries with Lua

- (int)registerLibrary:(const luaL_Reg *)functions metaFunctions:(const luaL_Reg *)metaFunctions {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wconstant-conversion"
    luaL_newlib(_L, functions);
    if (metaFunctions != nil) {
        luaL_newlib(_L, metaFunctions);
#pragma GCC diagnostic pop
        lua_setmetatable(_L, -2);
    }
    lua_newtable(_L);
    return luaL_ref(_L, LUA_REGISTRYINDEX);
}

- (int)registerLibraryWithObject:(char *)libraryName functions:(const luaL_Reg *)functions metaFunctions:(const luaL_Reg *)metaFunctions objectFunctions:(const luaL_Reg *)objectFunctions {

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wconstant-conversion"
    luaL_newlib(_L, objectFunctions);
#pragma GCC diagnostic pop
    lua_pushvalue(_L, -1);
    lua_setfield(_L, -2, "__index");
    lua_setfield(_L, LUA_REGISTRYINDEX, libraryName);

    int moduleRefTable = [self registerLibrary:functions metaFunctions:metaFunctions];

    return moduleRefTable;
}

- (int)luaRef:(int)refTable {
    NSAssert((refTable != LUA_NOREF && refTable != LUA_REFNIL), @"ERROR: LuaSkin::luaRef was passed a NOREF/REFNIL refTable", nil);
    if (lua_isnil(_L, -1)) {
        return LUA_REFNIL;
    }

    // Push refTable onto the stack
    lua_rawgeti(_L, LUA_REGISTRYINDEX, refTable);

    // Move refTable to second on the stack, underneath the object to reference
    lua_insert(_L, -2);

    // Reference the object at the top of the stack (pops it off)
    int ref = luaL_ref(_L, -2);

    // Remove refTable from the stack
    lua_remove(_L, -1);

    return ref;
}

- (int)luaUnref:(int)refTable ref:(int)ref {
    NSAssert((refTable != LUA_NOREF && refTable != LUA_REFNIL), @"ERROR: LuaSkin::luaUnref was passed a NOREF/REFNIL refTable", nil);
    if (ref != LUA_NOREF && ref != LUA_REFNIL) {
        // Push refTable onto the stack
        lua_rawgeti(_L, LUA_REGISTRYINDEX, refTable);

        // Dereference the supplied ref, from refTable
        luaL_unref(_L, -1, ref);

        // Remove refTable from the stack
        lua_remove(_L, -1);
    }
    return LUA_NOREF;
}

- (int)pushLuaRef:(int)refTable ref:(int)ref {
    NSAssert((refTable != LUA_NOREF && refTable != LUA_REFNIL), @"ERROR: LuaSkin::pushLuaRef was passed a NOREF/REFNIL refTable", nil);
    NSAssert((ref != LUA_NOREF && ref != LUA_REFNIL), @"ERROR: LuaSkin::luaRef was passed a NOREF/REFNIL ref", nil);

    // Push refTable onto the stack
    lua_rawgeti(_L, LUA_REGISTRYINDEX, refTable);

    // Push ref onto the stack
    int type = lua_rawgeti(_L, -1, ref);

    // Remove refTable from the stack
    lua_remove(_L, -2);

    return type;
}

#pragma mark - Helper functions for [- pushNSObject:object]

- (int)pushNSObject:(id)obj {
    return [self pushNSObject:obj preserveBitsInNSNumber:NO] ;
}

- (int)pushNSObject:(id)obj preserveBitsInNSNumber:(BOOL)bitsFlag {
    if (obj) { // you'd be surprised how often nil shows up when [NSNull null] is proper...
        // check for registered helpers

        for (id key in registeredNSHelperFunctions) {
            if ([obj isKindOfClass: NSClassFromString(key)]) {
                pushNSHelperFunction theFunc = (pushNSHelperFunction)[[registeredNSHelperFunctions objectForKey:key] pointerValue] ;
                return theFunc(_L, obj) ;
            }
        }

        // Check for built-in classes

        if ([obj isKindOfClass: [NSNull class]])       { return [self pushNSNull:obj] ; }
        if ([obj isKindOfClass: [NSNumber class]])     { return [self pushNSNumber:obj preserveBits:bitsFlag] ; }
        if ([obj isKindOfClass: [NSString class]])     { return [self pushNSString:obj] ; }
        if ([obj isKindOfClass: [NSData class]])       { return [self pushNSData:obj] ; }
        if ([obj isKindOfClass: [NSDate class]])       { return [self pushNSDate:obj] ; }
        if ([obj isKindOfClass: [NSArray class]])      { return [self pushNSArray:obj] ; }
        if ([obj isKindOfClass: [NSSet class]])        { return [self pushNSSet:obj] ; }
        if ([obj isKindOfClass: [NSDictionary class]]) { return [self pushNSDictionary:obj] ; }
        if ([obj isKindOfClass: [NSObject class]])     { return [self pushNSUnknown:obj] ; }

        // shouldn't happen -- the last check, NSObject, should catch everything not yet caught.

        NSLog(@"Uncaught NSObject type for '%@'", obj) ;
//         printToConsole(_L, (char *)[[NSString stringWithFormat:@"Uncaught NSObject type for '%@'", obj] UTF8String]) ;
        return [self pushNSUnknown:obj] ;

    } else {
        lua_pushnil(_L) ;
        return 1 ;
    }
}

- (int)pushNSObject:(id)obj withLocalHelpers:(pushNSHelpers*)fnList {
    return [self pushNSObject:obj withLocalHelpers:fnList preserveBitsInNSNumber:NO] ;
}

- (int)pushNSObject:(id)obj withLocalHelpers:(pushNSHelpers*)fnList preserveBitsInNSNumber:(BOOL)bitsFlag {
    for( pushNSHelpers *pos = fnList ; pos->name != NULL ; pos++) {
        if ([obj isKindOfClass: NSClassFromString([NSString stringWithUTF8String:pos->name])]) {
            return pos->func(_L, obj) ;
        }
    }
    return [self pushNSObject:obj preserveBitsInNSNumber:bitsFlag] ;
}

- (void)registerPushNSHelper:(pushNSHelperFunction)helperFN forClass:(char*)className {
    [registeredNSHelperFunctions setObject:[NSValue valueWithPointer:(void *)helperFN]
                                    forKey:[NSString stringWithUTF8String:className]] ;
}

- (void)unregisterPushNSHelperForClass:(char*)className {
    [registeredNSHelperFunctions removeObjectForKey:[NSString stringWithUTF8String:className]] ;
}

// Helper functions for [- pushNSObject:object]
// Can also be called directly if type of object is known

- (int)pushNSNull:(__unused id)obj {
    lua_pushnil(_L);
    return 1 ;
}

- (int)pushNSNumber:(id)obj {
    return [self pushNSNumber:obj preserveBits:NO] ;
}

- (int)pushNSNumber:(id)obj preserveBits:(BOOL)bitsOverNumber{
    if ([obj isKindOfClass: [NSNumber class]]) {
        NSNumber    *number = obj ;
        if (number == (id)kCFBooleanTrue)
            lua_pushboolean(_L, YES);
        else if (number == (id)kCFBooleanFalse)
            lua_pushboolean(_L, NO);
        else {
            switch([number objCType][0]) {
                case 'c': lua_pushinteger(_L, [number charValue]) ; break ;
                case 'C': lua_pushinteger(_L, [number unsignedCharValue]) ; break ;

                case 'i': lua_pushinteger(_L, [number intValue]) ; break ;
                case 'I': lua_pushinteger(_L, [number unsignedIntValue]) ; break ;

                case 's': lua_pushinteger(_L, [number shortValue]) ; break ;
                case 'S': lua_pushinteger(_L, [number unsignedShortValue]) ; break ;

                case 'l': lua_pushinteger(_L, [number longValue]) ; break ;
                case 'L': lua_pushinteger(_L, (long long)[number unsignedLongValue]) ; break ;

                case 'q': lua_pushinteger(_L, [number longLongValue]) ; break ;

                // Lua only does signed long long, not unsigned, so we keep it an integer as
                // far as we can; after that, sorry -- lua has to treat it as a number (real)
                // or it will wrap and we lose the whole point of being unsigned.
                case 'Q': if (bitsOverNumber) {
                              lua_pushinteger(_L, (long long)[number unsignedLongLongValue]) ;
                          } else {
                              if ([number unsignedLongLongValue] < 0x8000000000000000)
                                  lua_pushinteger(_L, (long long)[number unsignedLongLongValue]) ;
                              else
                                  lua_pushnumber(_L, [number unsignedLongLongValue]) ;
                          }
                          break ;

                case 'f': lua_pushnumber(_L,  [number floatValue]) ; break ;
                case 'd': lua_pushnumber(_L,  [number doubleValue]) ; break ;

                default:
                    NSLog(@"Unrecognized numerical type '%s' for '%@'", [number objCType], number) ;
    //                 printToConsole(_L, (char *)[[NSString stringWithFormat:@"Unrecognized numerical type '%s' for '%@'", [number objCType], number] UTF8String]) ;
                    lua_pushnumber(_L, [number doubleValue]) ;
                    break ;
            }
        }
    } else {
        lua_pushnil(_L) ; // Not an NSNumber
    }
    return 1 ;
}

- (int)pushNSString:(id)obj {
    if ([obj isKindOfClass: [NSString class]]) {
        NSString *string = obj;
        lua_pushstring(_L, [string UTF8String]);
    } else {
        lua_pushnil(_L) ; // Not an NSString
    }
    return 1 ;
}

- (int)pushNSData:(id)obj {
    if ([obj isKindOfClass: [NSData class]]) {
        NSData *data = obj;
        lua_pushlstring(_L, [data bytes], [data length]) ;
    } else {
        lua_pushnil(_L) ; // Not an NSData
    }
    return 1 ;
}

- (int)pushNSDate:(id)obj {
    if ([obj isKindOfClass: [NSDate class]]) {
        NSDate *date = obj ;
        lua_pushinteger(_L, lround([date timeIntervalSince1970]));
    } else {
        lua_pushnil(_L) ; // Not an NSDate
    }
    return 1 ;
}

- (int)pushNSArray:(id)obj {
    if ([obj isKindOfClass: [NSArray class]]) {
        NSArray* list = obj;
        lua_newtable(_L);
        for (id item in list) {
            [self pushNSObject:item];
            lua_rawseti(_L, -2, luaL_len(_L, -2) + 1) ;
        }
    } else {
        lua_pushnil(_L) ; // Not an NSArray
    }
    return 1 ;
}

- (int)pushNSSet:(id)obj {
    if ([obj isKindOfClass: [NSSet class]]) {
        NSSet* list = obj;
        lua_newtable(_L);
        for (id item in list) {
            [self pushNSObject:item];
            lua_rawseti(_L, -2, luaL_len(_L, -2) + 1) ;
        }
    } else {
        lua_pushnil(_L) ; // Not an NSSet
    }
    return 1 ;
}

- (int)pushNSDictionary:(id)obj {
    if ([obj isKindOfClass: [NSDictionary class]]) {
        NSArray *keys = [obj allKeys];
        NSArray *values = [obj allValues];
        lua_newtable(_L);
        for (unsigned long i = 0; i < [keys count]; i++) {
            [self pushNSObject:[keys objectAtIndex:i]];
            [self pushNSObject:[values objectAtIndex:i]];
            lua_settable(_L, -3);
        }
    } else {
        lua_pushnil(_L) ; // Not an NSDictionary
    }
    return 1 ;
}

- (int)pushNSUnknown:(id)obj {
    lua_pushstring(_L, [[NSString stringWithFormat:@"%@", obj] UTF8String]) ;
    return 1 ;
}

@end
