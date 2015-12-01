//
//  Skin.m
//  LuaSkin
//
//  Created by Chris Jones on 11/06/2015.
//  Copyright (c) 2015 Hammerspoon Project Authors. All rights reserved.
//

#import "Skin.h"

// maxn   returns the largest numeric key in the table
// countn returns the number of items of any key type in the table

// Shamelessly "borrowed" and tweaked from the lua 5.1 source... see http://www.lua.org/source/5.1/ltablib.c.html
static lua_Integer maxn (lua_State *L, int idx) {
  lua_Integer max = 0;
  luaL_checktype(L, idx, LUA_TTABLE);
  lua_pushnil(L);  /* first key */
  while (lua_next(L, idx)) {
    lua_pop(L, 1);  /* remove value */
    if (lua_type(L, -1) == LUA_TNUMBER && lua_isinteger(L, -1)) {
      lua_Integer v = lua_tointeger(L, -1);
      if (v > max) max = v;
    }
  }
  return max ;
}

static lua_Integer countn (lua_State *L, int idx) {
  lua_Integer max = 0;
  luaL_checktype(L, idx, LUA_TTABLE);
  lua_pushnil(L);  /* first key */
  while (lua_next(L, idx)) {
    lua_pop(L, 1);  /* remove value */
    max++ ;
  }
  return max ;
}

// Extension to LuaSkin class for conversion support
@interface LuaSkin (conversionSupport)

// internal methods for pushNSObject
- (int)pushNSObject:(id)obj preserveBitsInNSNumber:(BOOL)bitsFlag
                                alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (int)pushNSNumber:(id)obj preserveBits:(BOOL)bitsOverNumber ;
- (int)pushNSArray:(id)obj preserveBitsInNSNumber:(BOOL)bitsFlag
                               alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (int)pushNSSet:(id)obj preserveBitsInNSNumber:(BOOL)bitsFlag
                             alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (int)pushNSDictionary:(id)obj preserveBitsInNSNumber:(BOOL)bitsFlag
                                    alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;

// internal methods for toNSObjectAtIndex
- (id)toNSObjectAtIndex:(int)idx alreadySeenObjects:(NSMutableDictionary *)alreadySeen
                                   allowSelfReference:(BOOL)allow ;
- (id)tableAtIndex:(int)idx alreadySeenObjects:(NSMutableDictionary *)alreadySeen
                              allowSelfReference:(BOOL)allow;
@end

@implementation LuaSkin

#pragma mark - Skin Properties

@synthesize L = _L;

NSMutableDictionary *registeredNSHelperFunctions ;
NSMutableDictionary *registeredNSHelperLocations ;
NSMutableDictionary *registeredLuaObjectHelperFunctions ;
NSMutableDictionary *registeredLuaObjectHelperLocations ;

#pragma mark - Class lifecycle

+ (id)shared {
    static LuaSkin *sharedLuaSkin = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedLuaSkin = [[self alloc] init];
        registeredNSHelperFunctions = [[NSMutableDictionary alloc] init] ;
        registeredNSHelperLocations = [[NSMutableDictionary alloc] init] ;
        registeredLuaObjectHelperFunctions = [[NSMutableDictionary alloc] init] ;
        registeredLuaObjectHelperLocations = [[NSMutableDictionary alloc] init] ;
    });
    if (![NSThread isMainThread]) {
        NSLog(@"GRAVE BUG: LUA EXECUTION ON NON-MAIN THREAD");
        NSException* myException = [NSException
                                    exceptionWithName:@"LuaOnNonMainThread"
                                    reason:@"Lua execution is happening on a non-main thread"
                                    userInfo:nil];
        @throw myException;
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
        [registeredNSHelperFunctions removeAllObjects] ;
        [registeredNSHelperLocations removeAllObjects] ;
        [registeredLuaObjectHelperFunctions removeAllObjects] ;
        [registeredLuaObjectHelperLocations removeAllObjects] ;
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
        lua_remove(_L, -2) ; // remove the message handler
        return NO;
    }

    lua_remove(_L, -nresults - 1) ; // remove the message handler
    return YES;
}

#pragma mark - Methods for registering libraries with Lua

- (int)registerLibrary:(const luaL_Reg *)functions metaFunctions:(const luaL_Reg *)metaFunctions {
    NSAssert(functions != NULL, @"functions can not be NULL", nil);

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

    NSAssert(libraryName != NULL, @"libraryName can not be NULL", nil);
    NSAssert(functions != NULL, @"functions can not be NULL (%s)", libraryName);
    NSAssert(objectFunctions != NULL, @"objectFunctions can not be NULL (%s)", libraryName);

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

- (void)registerObject:(char *)objectName objectFunctions:(const luaL_Reg *)objectFunctions {
    NSAssert(objectName != NULL, @"objectName can not be NULL", nil);
    NSAssert(objectFunctions != NULL, @"objectFunctions can not be NULL (%s)", objectName);

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wconstant-conversion"
    luaL_newlib(_L, objectFunctions);
#pragma GCC diagnostic pop
    lua_pushvalue(_L, -1);
    lua_setfield(_L, -2, "__index");
    lua_setfield(_L, LUA_REGISTRYINDEX, objectName);
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

- (void)checkArgs:(int)firstArg, ... {
    int idx = 1;
    int numArgs = lua_gettop(_L);
    int spec = firstArg;
    int lsType = -1;

    va_list args;
    va_start(args, firstArg);

    while (true) {
        if (spec == LS_TBREAK) {
            idx--;
            break;
        }

        int luaType = lua_type(_L, idx);
        char *userdataTag;

        // If LS_TANY is set, we don't care what the type is, just that there was a type.
        if (spec & LS_TANY && luaType != LUA_TNONE)
            goto nextarg;

        switch (luaType) {
            case LUA_TNONE:
                if (spec & LS_TOPTIONAL) {
                    idx--;
                    goto nextarg;
                }
                lsType = LS_TNONE;
                // FIXME: should there be a break here? If not, document why not
            case LUA_TNIL:
                lsType = LS_TNIL;
                break;
            case LUA_TBOOLEAN:
                lsType = LS_TBOOLEAN;
                break;
            case LUA_TNUMBER:
                lsType = LS_TNUMBER;
                break;
            case LUA_TSTRING:
                lsType = LS_TSTRING;
                break;
            case LUA_TFUNCTION:
                lsType = LS_TFUNCTION;
                break;
            case LUA_TTABLE:
                lsType = LS_TTABLE;
                break;
            case LUA_TUSERDATA:
                lsType = LS_TUSERDATA;

                // We have to duplicate this check here, because if the user wasn't supposed to pass userdata, we won't have a valid userdataTag value available
                if (!(spec & lsType)) {
                    luaL_error(_L, "ERROR: incorrect type '%s' for argument %d", luaL_typename(_L, idx), idx);
                }

                userdataTag = va_arg(args, char*);
                if (!userdataTag || strlen(userdataTag) == 0 || !luaL_testudata(_L, idx, userdataTag)) {
                    luaL_error(_L, "ERROR: incorrect userdata type for argument %d (expected %s)", idx, userdataTag);
                }
                break;

            default:
                luaL_error(_L, "ERROR: unknown type '%s' for argument %d", luaL_typename(_L, idx), idx);
                break;
        }

        if (!(spec & LS_TANY) && !(spec & lsType)) {
            luaL_error(_L, "ERROR: incorrect type '%s' for argument %d", luaL_typename(_L, idx), idx);
        }
nextarg:
        spec = va_arg(args, int);
        idx++;
    }
    va_end(args);

    if (idx != numArgs) {
        luaL_error(_L, "ERROR: incorrect number of arguments. Expected %d, got %d", idx, numArgs);
    }
}

#pragma mark - Conversion from NSObjects into Lua objects

- (int)pushNSObject:(id)obj { return [self pushNSObject:obj preserveBitsInNSNumber:NO] ; }

- (int)pushNSObject:(id)obj preserveBitsInNSNumber:(BOOL)bitsFlag {
    NSMutableDictionary *alreadySeen = [[NSMutableDictionary alloc] init] ;

    [self pushNSObject:obj preserveBitsInNSNumber:bitsFlag
                               alreadySeenObjects:alreadySeen];

    for (id entry in alreadySeen) {
        luaL_unref(_L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:entry] intValue]) ;
    }
    return 1 ;
}

- (void)registerPushNSHelper:(pushNSHelperFunction)helperFN forClass:(char*)className {
    if (className && helperFN) {
        if ([registeredNSHelperFunctions objectForKey:[NSString stringWithUTF8String:className]]) {
            luaL_error(_L, "registerPushNSHelper:forClass:%s already defined at %s", className,
              [[registeredNSHelperLocations objectForKey:[NSString stringWithUTF8String:className]] UTF8String]) ;
        } else {
            int level = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"HSLuaSkinRegisterRequireLevel"];
            if (level == 0) level = 3 ;

            luaL_where(_L, level) ;
            NSString *locationString = [NSString stringWithFormat:@"%s", lua_tostring(_L, -1)] ;
            [registeredNSHelperLocations setObject:locationString
                                            forKey:[NSString stringWithUTF8String:className]] ;
            [registeredNSHelperFunctions setObject:[NSValue valueWithPointer:(void *)helperFN]
                                            forKey:[NSString stringWithUTF8String:className]] ;
            lua_pop(_L, 1) ;
        }
    } else {
        luaL_error(_L, "registerPushNSHelper:forClass: requires both helperFN and className") ;
    }
}

- (int)pushNSRect:(NSRect)theRect {
    lua_newtable(_L) ;
    lua_pushnumber(_L, theRect.origin.x) ; lua_setfield(_L, -2, "x") ;
    lua_pushnumber(_L, theRect.origin.y) ; lua_setfield(_L, -2, "y") ;
    lua_pushnumber(_L, theRect.size.width) ; lua_setfield(_L, -2, "w") ;
    lua_pushnumber(_L, theRect.size.height) ; lua_setfield(_L, -2, "h") ;
    return 1;
}

- (int)pushNSPoint:(NSPoint)thePoint {
    lua_newtable(_L) ;
    lua_pushnumber(_L, thePoint.x) ; lua_setfield(_L, -2, "x") ;
    lua_pushnumber(_L, thePoint.y) ; lua_setfield(_L, -2, "y") ;
    return 1;
}

- (int)pushNSSize:(NSSize)theSize {
    lua_newtable(_L) ;
    lua_pushnumber(_L, theSize.width) ; lua_setfield(_L, -2, "w") ;
    lua_pushnumber(_L, theSize.height) ; lua_setfield(_L, -2, "h") ;
    return 1;
}

#pragma mark - Conversion from lua objects into NSObjects

- (id)toNSObjectAtIndex:(int)idx { return [self toNSObjectAtIndex:idx allowSelfReference:NO] ; }

- (id)toNSObjectAtIndex:(int)idx allowSelfReference:(BOOL)allow {
    NSMutableDictionary *alreadySeen = [[NSMutableDictionary alloc] init] ;

    return [self toNSObjectAtIndex:idx alreadySeenObjects:alreadySeen allowSelfReference:allow] ;
}

- (id)luaObjectAtIndex:(int)idx toClass:(char *)className {
    NSString *theClass = [NSString stringWithUTF8String:(const char *)className] ;

    for (id key in registeredLuaObjectHelperFunctions) {
        if ([theClass isEqualToString:key]) {
            luaObjectHelperFunction theFunc = (luaObjectHelperFunction)[[registeredLuaObjectHelperFunctions objectForKey:key] pointerValue] ;
            return theFunc(_L, lua_absindex(_L, idx)) ;
        }
    }
    return nil ;
}

- (void)registerLuaObjectHelper:(luaObjectHelperFunction)helperFN forClass:(char*)className {
    if (className && helperFN) {
        if ([registeredLuaObjectHelperFunctions objectForKey:[NSString stringWithUTF8String:className]]) {
            luaL_error(_L, "registerLuaObjectHelper:forClass:%s already defined at %s", className,
              [[registeredLuaObjectHelperLocations objectForKey:[NSString stringWithUTF8String:className]] UTF8String]) ;
        } else {
            int level = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"HSLuaSkinRegisterRequireLevel"];
            if (level == 0) level = 3 ;

            luaL_where(_L, level) ;
            NSString *locationString = [NSString stringWithFormat:@"%s", lua_tostring(_L, -1)] ;
            [registeredLuaObjectHelperLocations setObject:locationString
                                               forKey:[NSString stringWithUTF8String:className]] ;
            [registeredLuaObjectHelperFunctions setObject:[NSValue valueWithPointer:(void *)helperFN]
                                               forKey:[NSString stringWithUTF8String:className]] ;
            lua_pop(_L, 1) ;
        }
    } else {
        luaL_error(_L, "registerLuaObjectHelper:forClass: requires both helperFN and className") ;
    }
}

- (NSRect)tableToRectAtIndex:(int)idx {
    luaL_checktype(_L, idx, LUA_TTABLE);
    CGFloat x = (lua_getfield(_L, idx, "x") != LUA_TNIL) ? luaL_checknumber(_L, -1) : 0.0 ;
    CGFloat y = (lua_getfield(_L, idx, "y") != LUA_TNIL) ? luaL_checknumber(_L, -1) : 0.0 ;
    CGFloat w = (lua_getfield(_L, idx, "w") != LUA_TNIL) ? luaL_checknumber(_L, -1) : 0.0 ;
    CGFloat h = (lua_getfield(_L, idx, "h") != LUA_TNIL) ? luaL_checknumber(_L, -1) : 0.0 ;
    lua_pop(_L, 4);
    return NSMakeRect(x, y, w, h);
}

- (NSPoint)tableToPointAtIndex:(int)idx {
    luaL_checktype(_L, idx, LUA_TTABLE);
    CGFloat x = (lua_getfield(_L, idx, "x") != LUA_TNIL) ? luaL_checknumber(_L, -1) : 0.0 ;
    CGFloat y = (lua_getfield(_L, idx, "y") != LUA_TNIL) ? luaL_checknumber(_L, -1) : 0.0 ;
    lua_pop(_L, 2);
    return NSMakePoint(x, y);
}

- (NSSize)tableToSizeAtIndex:(int)idx {
    luaL_checktype(_L, idx, LUA_TTABLE);
    CGFloat w = (lua_getfield(_L, idx, "w") != LUA_TNIL) ? luaL_checknumber(_L, -1) : 0.0 ;
    CGFloat h = (lua_getfield(_L, idx, "h") != LUA_TNIL) ? luaL_checknumber(_L, -1) : 0.0 ;
    lua_pop(_L, 2);
    return NSMakeSize(w, h);
}

#pragma mark - Other helpers

- (BOOL)isValidUTF8AtIndex:(int)idx {
    if (lua_type(_L, idx) != LUA_TSTRING && lua_type(_L, idx) != LUA_TNUMBER) return NO ;

    size_t len ;
    unsigned char *str = (unsigned char *)lua_tolstring(_L, idx, &len) ;

    size_t i = 0;

    while (i < len) {
        if (str[i] <= 0x7F) { /* 00..7F */
            i += 1;
        } else if (str[i] >= 0xC2 && str[i] <= 0xDF) { /* C2..DF 80..BF */
            if (i + 1 < len) { /* Expect a 2nd byte */
                if (str[i + 1] < 0x80 || str[i + 1] > 0xBF) return NO;
            } else
                return NO;
            i += 2;
        } else if (str[i] == 0xE0) { /* E0 A0..BF 80..BF */
            if (i + 2 < len) { /* Expect a 2nd and 3rd byte */
                if (str[i + 1] < 0xA0 || str[i + 1] > 0xBF) return NO;
                if (str[i + 2] < 0x80 || str[i + 2] > 0xBF) return NO;
            } else
                return NO;
            i += 3;
        } else if (str[i] >= 0xE1 && str[i] <= 0xEC) { /* E1..EC 80..BF 80..BF */
            if (i + 2 < len) { /* Expect a 2nd and 3rd byte */
                if (str[i + 1] < 0x80 || str[i + 1] > 0xBF) return NO;
                if (str[i + 2] < 0x80 || str[i + 2] > 0xBF) return NO;
            } else
                return NO;
            i += 3;
        } else if (str[i] == 0xED) { /* ED 80..9F 80..BF */
            if (i + 2 < len) { /* Expect a 2nd and 3rd byte */
                if (str[i + 1] < 0x80 || str[i + 1] > 0x9F) return NO;
                if (str[i + 2] < 0x80 || str[i + 2] > 0xBF) return NO;
            } else
                return NO;
            i += 3;
        } else if (str[i] >= 0xEE && str[i] <= 0xEF) { /* EE..EF 80..BF 80..BF */
            if (i + 2 < len) { /* Expect a 2nd and 3rd byte */
                if (str[i + 1] < 0x80 || str[i + 1] > 0xBF) return NO;
                if (str[i + 2] < 0x80 || str[i + 2] > 0xBF) return NO;
            } else
                return NO;
            i += 3;
        } else if (str[i] == 0xF0) { /* F0 90..BF 80..BF 80..BF */
            if (i + 3 < len) { /* Expect a 2nd, 3rd 3th byte */
                if (str[i + 1] < 0x90 || str[i + 1] > 0xBF) return NO;
                if (str[i + 2] < 0x80 || str[i + 2] > 0xBF) return NO;
                if (str[i + 3] < 0x80 || str[i + 3] > 0xBF) return NO;
            } else
                return NO;
            i += 4;
        } else if (str[i] >= 0xF1 && str[i] <= 0xF3) { /* F1..F3 80..BF 80..BF 80..BF */
            if (i + 3 < len) { /* Expect a 2nd, 3rd 3th byte */
                if (str[i + 1] < 0x80 || str[i + 1] > 0xBF) return NO;
                if (str[i + 2] < 0x80 || str[i + 2] > 0xBF) return NO;
                if (str[i + 3] < 0x80 || str[i + 3] > 0xBF) return NO;
            } else
                return NO;
            i += 4;
        } else if (str[i] == 0xF4) { /* F4 80..8F 80..BF 80..BF */
            if (i + 3 < len) { /* Expect a 2nd, 3rd 3th byte */
                if (str[i + 1] < 0x80 || str[i + 1] > 0x8F) return NO;
                if (str[i + 2] < 0x80 || str[i + 2] > 0xBF) return NO;
                if (str[i + 3] < 0x80 || str[i + 3] > 0xBF) return NO;
            } else
                return NO;
            i += 4;
        } else
            return NO;
    }
    return YES;
}

- (BOOL)requireModule:(char *)moduleName {
    lua_getglobal(_L, "require"); lua_pushstring(_L, moduleName) ;
    return [self protectedCallAndTraceback:1 nresults:1] ;
}

#pragma mark - conversionSupport extensions to LuaSkin class

- (int)pushNSObject:(id)obj preserveBitsInNSNumber:(BOOL)bitsFlag
                                alreadySeenObjects:(NSMutableDictionary *)alreadySeen {

    if (obj) {
// NOTE: We catch self-referential loops, do we also need a recursive depth?  Will crash at depth of 512...
        if ([alreadySeen objectForKey:obj]) {
            lua_rawgeti(_L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:obj] intValue]) ;
            return 1 ;
        }

        // check for registered helpers

        for (id key in registeredNSHelperFunctions) {
            if ([obj isKindOfClass: NSClassFromString(key)]) {
                pushNSHelperFunction theFunc = (pushNSHelperFunction)[[registeredNSHelperFunctions objectForKey:key] pointerValue] ;
                return theFunc(_L, obj) ;
            }
        }

        // Check for built-in classes

        if ([obj isKindOfClass:[NSNull class]]) {
            lua_pushnil(_L) ;
        } else if ([obj isKindOfClass:[NSNumber class]]) {
            [self pushNSNumber:obj preserveBits:bitsFlag] ;
        } else if ([obj isKindOfClass:[NSString class]]) {
                size_t size = [(NSString *)obj lengthOfBytesUsingEncoding:NSUTF8StringEncoding] ;
                lua_pushlstring(_L, [(NSString *)obj UTF8String], size) ;
//             lua_pushstring(_L, [(NSString *)obj UTF8String]);
        } else if ([obj isKindOfClass:[NSData class]]) {
            lua_pushlstring(_L, [(NSData *)obj bytes], [(NSData *)obj length]) ;
        } else if ([obj isKindOfClass:[NSDate class]]) {
            lua_pushinteger(_L, lround([(NSDate *)obj timeIntervalSince1970])) ;
        } else if ([obj isKindOfClass:[NSArray class]]) {
            [self pushNSArray:obj preserveBitsInNSNumber:bitsFlag alreadySeenObjects:alreadySeen] ;
        } else if ([obj isKindOfClass:[NSSet class]]) {
            [self pushNSSet:obj preserveBitsInNSNumber:bitsFlag alreadySeenObjects:alreadySeen] ;
        } else if ([obj isKindOfClass:[NSDictionary class]]) {
            [self pushNSDictionary:obj preserveBitsInNSNumber:bitsFlag alreadySeenObjects:alreadySeen] ;
        } else if ([obj isKindOfClass:[NSObject class]]) {
            lua_pushstring(_L, [[NSString stringWithFormat:@"%@", obj] UTF8String]) ;
        } else {
        // shouldn't happen -- the last check, NSObject, should catch everything not yet caught, so log it.
            NSLog(@"Uncaught NSObject type for '%@'", obj) ;
            lua_pushstring(_L, [[NSString stringWithFormat:@"%@", obj] UTF8String]) ;
        }
    } else {
        lua_pushnil(_L) ;
    }
    return 1 ;
}

- (int)pushNSNumber:(id)obj preserveBits:(BOOL)bitsOverNumber{
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

            // Lua only does signed long long, not unsigned, so we have two options
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
                lua_pushnumber(_L, [number doubleValue]) ;
                break ;
        }
    }
    return 1 ;
}

- (int)pushNSArray:(id)obj preserveBitsInNSNumber:(BOOL)bitsFlag
                               alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
    NSArray* list = obj;
    lua_newtable(_L);
    [alreadySeen setObject:[NSNumber numberWithInt:luaL_ref(_L, LUA_REGISTRYINDEX)] forKey:obj] ;
    lua_rawgeti(_L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:obj] intValue]) ; // put it back on the stack
    for (id item in list) {
        [self pushNSObject:item preserveBitsInNSNumber:bitsFlag
                                    alreadySeenObjects:alreadySeen];
        lua_rawseti(_L, -2, luaL_len(_L, -2) + 1) ;
    }
    return 1 ;
}

- (int)pushNSSet:(id)obj preserveBitsInNSNumber:(BOOL)bitsFlag
                             alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
    if ([obj isKindOfClass: [NSSet class]]) {
        NSSet* list = obj;
        lua_newtable(_L);
        [alreadySeen setObject:[NSNumber numberWithInt:luaL_ref(_L, LUA_REGISTRYINDEX)] forKey:obj] ;
        lua_rawgeti(_L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:obj] intValue]) ; // put it back on the stack
        for (id item in list) {
            [self pushNSObject:item preserveBitsInNSNumber:bitsFlag
                                        alreadySeenObjects:alreadySeen];
            lua_rawseti(_L, -2, luaL_len(_L, -2) + 1) ;
        }
    } else {
        lua_pushnil(_L) ; // Not an NSSet
    }
    return 1 ;
}

- (int)pushNSDictionary:(id)obj preserveBitsInNSNumber:(BOOL)bitsFlag
                                    alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
    NSArray *keys = [obj allKeys];
    NSArray *values = [obj allValues];
    lua_newtable(_L);
    [alreadySeen setObject:[NSNumber numberWithInt:luaL_ref(_L, LUA_REGISTRYINDEX)] forKey:obj] ;
    lua_rawgeti(_L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:obj] intValue]) ; // put it back on the stack
    for (unsigned long i = 0; i < [keys count]; i++) {
        [self pushNSObject:[keys objectAtIndex:i] preserveBitsInNSNumber:bitsFlag
                                                      alreadySeenObjects:alreadySeen];
        [self pushNSObject:[values objectAtIndex:i] preserveBitsInNSNumber:bitsFlag
                                                        alreadySeenObjects:alreadySeen];
        lua_settable(_L, -3);
    }
    return 1 ;
}

- (id)toNSObjectAtIndex:(int)idx
       alreadySeenObjects:(NSMutableDictionary *)alreadySeen
       allowSelfReference:(BOOL)allow {

    int realIndex = lua_absindex(_L, idx) ;
    NSMutableArray *seenObject = [alreadySeen objectForKey:[NSValue valueWithPointer:lua_topointer(_L, idx)]] ;
    if (seenObject) {
        if ([[seenObject lastObject] isEqualToNumber:@(NO)] && allow == NO) {
            luaL_error(_L, "lua table cannot contain self-references") ;
            return nil ;
        } else {
            return [seenObject firstObject] ;
        }
    }
    switch (lua_type(_L, realIndex)) {
        case LUA_TNUMBER:
            if (lua_isinteger(_L, idx))
                return @(lua_tointeger(_L, idx)) ;
            else
                return @(lua_tonumber(_L, idx));
            break ;
        case LUA_TSTRING:
            if ([self isValidUTF8AtIndex:idx]) {
                size_t size ;
                unsigned char *string = (unsigned char *)lua_tolstring(_L, idx, &size) ;
                return [[NSString alloc] initWithData:[NSData dataWithBytes:(void *)string length:size] encoding: NSUTF8StringEncoding] ;
//                 return [NSString stringWithUTF8String:(char *)lua_tostring(_L, idx)];
            } else {
                size_t size ;
                unsigned char *junk = (unsigned char *)lua_tolstring(_L, idx, &size) ;
                return [NSData dataWithBytes:(void *)junk length:size] ;
            }
            break ;
        case LUA_TNIL:
            return [NSNull null] ;
            break ;
        case LUA_TBOOLEAN:
            return lua_toboolean(_L, idx) ? (id)kCFBooleanTrue : (id)kCFBooleanFalse;
            break ;
        case LUA_TTABLE:
            return [self tableAtIndex:realIndex alreadySeenObjects:alreadySeen allowSelfReference:allow] ;
            break ;
        default:
            return [NSString stringWithFormat:@"%s", luaL_tolstring(_L, idx, NULL)];
            break ;
    }
}

- (id)tableAtIndex:(int)idx alreadySeenObjects:(NSMutableDictionary *)alreadySeen
                              allowSelfReference:(BOOL)allow {
    id result ;

    if (maxn(_L, lua_absindex(_L, idx)) == countn(_L, lua_absindex(_L, idx))) {
        result = (NSMutableArray *) [[NSMutableArray alloc] init] ;
    } else {
        result = (NSMutableDictionary *) [[NSMutableDictionary alloc] init] ;
    }
    [alreadySeen setObject:@[result, @(NO)] forKey:[NSValue valueWithPointer:lua_topointer(_L, idx)]] ;

    if ([result isKindOfClass: [NSArray class]]) {
        lua_Integer tableLength = countn(_L, lua_absindex(_L, idx)) ;
        for (lua_Integer i = 0; i < tableLength ; i++) {
            lua_geti(_L, lua_absindex(_L, idx), i + 1) ;
            id val = [self toNSObjectAtIndex:-1 alreadySeenObjects:alreadySeen allowSelfReference:allow] ;
            [result addObject:val] ;
            lua_pop(_L, 1) ;
        }
    } else {
        lua_pushnil(_L);
        while (lua_next(_L, lua_absindex(_L, idx)) != 0) {
            id key = [self toNSObjectAtIndex:-2 alreadySeenObjects:alreadySeen allowSelfReference:allow] ;
            id val = [self toNSObjectAtIndex:lua_gettop(_L) alreadySeenObjects:alreadySeen allowSelfReference:allow] ;
            [result setValue:val forKey:key];
            lua_pop(_L, 1);
        }
    }

    [alreadySeen setObject:@[result, @(YES)] forKey:[NSValue valueWithPointer:lua_topointer(_L, idx)]] ;
    return result ;
}

@end
