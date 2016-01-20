//
//  Skin.m
//  LuaSkin
//
//  Created by Chris Jones on 11/06/2015.
//  Copyright (c) 2015 Hammerspoon Project Authors. All rights reserved.
//

#import "Skin.h"

typedef struct pushNSHelpers {
    const char            *name;
    pushNSHelperFunction  func;
} pushNSHelpers;

typedef struct luaObjectHelpers {
    const char          *name ;
    luaObjectHelperFunction func ;
} luaObjectHelpers ;

// Extension to LuaSkin class for conversion support
@interface LuaSkin (conversionSupport)

// internal methods for pushNSObject
- (int)pushNSObject:(id)obj     withOptions:(LS_NSConversionOptions)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (int)pushNSNumber:(id)obj     withOptions:(LS_NSConversionOptions)options ;
- (int)pushNSArray:(id)obj      withOptions:(LS_NSConversionOptions)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (int)pushNSSet:(id)obj        withOptions:(LS_NSConversionOptions)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (int)pushNSDictionary:(id)obj withOptions:(LS_NSConversionOptions)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;

// internal methods for toNSObjectAtIndex
- (id)toNSObjectAtIndex:(int)idx withOptions:(LS_NSConversionOptions)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (id)tableAtIndex:(int)idx      withOptions:(LS_NSConversionOptions)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen;
@end

@implementation LuaSkin

#pragma mark - Skin Properties

@synthesize L        = _L;
@synthesize delegate = _delegate;

NSMutableDictionary *registeredNSHelperFunctions ;
NSMutableDictionary *registeredNSHelperLocations ;
NSMutableDictionary *registeredLuaObjectHelperFunctions ;
NSMutableDictionary *registeredLuaObjectHelperLocations ;
NSMutableDictionary *registeredLuaObjectHelperUserdataMappings;

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
        registeredLuaObjectHelperUserdataMappings = [[NSMutableDictionary alloc] init];
    });
    if (![NSThread isMainThread]) {
        NSLog(@"GRAVE BUG: LUA EXECUTION ON NON-MAIN THREAD");
        for (NSString *stackSymbol in [NSThread callStackSymbols]) {
            NSLog(@"Previous stack symbol: %@", stackSymbol);
        }
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
        [registeredLuaObjectHelperUserdataMappings removeAllObjects];
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

    [self registerObject:libraryName objectFunctions:objectFunctions];

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
    lua_pushstring(_L, objectName);
    lua_setfield(_L, -2, "__type");
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

- (int)luaRef:(int)refTable atIndex:(int)idx {
    lua_pushvalue(_L, idx);
    return [self luaRef:refTable];
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

- (int)pushNSObject:(id)obj { return [self pushNSObject:obj withOptions:LS_NSNone] ; }

- (int)pushNSObject:(id)obj withOptions:(LS_NSConversionOptions)options {
    NSMutableDictionary *alreadySeen = [[NSMutableDictionary alloc] init] ;

    int results = [self pushNSObject:obj withOptions:options alreadySeenObjects:alreadySeen];

    for (id entry in alreadySeen) {
        luaL_unref(_L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:entry] intValue]) ;
    }
    return results ;
}

- (BOOL)registerPushNSHelper:(pushNSHelperFunction)helperFN forClass:(char*)className {
    BOOL allGood = NO ;
// this hackery assumes that this method is only called from within the luaopen_* function of a module and
// attempts to compensate for a wrapper to "require"... I doubt anyone is actually using it anymore.
    int level = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"HSLuaSkinRegisterRequireLevel"];
    if (level == 0) level = 3 ;

    if (className && helperFN) {
        if ([registeredNSHelperFunctions objectForKey:[NSString stringWithUTF8String:className]]) {
            [self logAtLevel:LS_LOG_WARN
                 withMessage:[NSString stringWithFormat:@"registerPushNSHelper:forClass:%s already defined at %@",
                                                        className,
                                                        [registeredNSHelperLocations objectForKey:[NSString stringWithUTF8String:className]]]
                fromStackPos:level] ;
        } else {
            luaL_where(_L, level) ;
            NSString *locationString = [NSString stringWithFormat:@"%s", lua_tostring(_L, -1)] ;
            [registeredNSHelperLocations setObject:locationString
                                            forKey:[NSString stringWithUTF8String:className]] ;
            [registeredNSHelperFunctions setObject:[NSValue valueWithPointer:(void *)helperFN]
                                            forKey:[NSString stringWithUTF8String:className]] ;
            lua_pop(_L, 1) ;
            allGood = YES ;
        }
    } else {
        [self logAtLevel:LS_LOG_WARN
             withMessage:@"registerPushNSHelper:forClass: requires both helperFN and className"
             fromStackPos:level] ;
    }
    return allGood ;
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

- (id)toNSObjectAtIndex:(int)idx { return [self toNSObjectAtIndex:idx withOptions:LS_NSNone] ; }

- (id)toNSObjectAtIndex:(int)idx withOptions:(LS_NSConversionOptions)options {
    NSMutableDictionary *alreadySeen = [[NSMutableDictionary alloc] init] ;

    // We don't need to deref the already seen objects, like we do for pushNSObject because these are
    // all NSObjectes and not referenced in the LUA_REGISTRY... ARC will take care of this for us.

    return [self toNSObjectAtIndex:idx withOptions:options alreadySeenObjects:alreadySeen] ;
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

- (BOOL)registerLuaObjectHelper:(luaObjectHelperFunction)helperFN forClass:(char*)className {
    BOOL allGood = NO ;
// this hackery assumes that this method is only called from within the luaopen_* function of a module and
// attempts to compensate for a wrapper to "require"... I doubt anyone is actually using it anymore.
    int level = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"HSLuaSkinRegisterRequireLevel"];
    if (level == 0) level = 3 ;

    if (className && helperFN) {
        if ([registeredLuaObjectHelperFunctions objectForKey:[NSString stringWithUTF8String:className]]) {
            [self logAtLevel:LS_LOG_WARN
                 withMessage:[NSString stringWithFormat:@"registerLuaObjectHelper:forClass:%s already defined at %@",
                                                        className,
                                                        [registeredLuaObjectHelperFunctions objectForKey:[NSString stringWithUTF8String:className]]]
                fromStackPos:level] ;
        } else {
            luaL_where(_L, level) ;
            NSString *locationString = [NSString stringWithFormat:@"%s", lua_tostring(_L, -1)] ;
            [registeredLuaObjectHelperLocations setObject:locationString
                                               forKey:[NSString stringWithUTF8String:className]] ;
            [registeredLuaObjectHelperFunctions setObject:[NSValue valueWithPointer:(void *)helperFN]
                                               forKey:[NSString stringWithUTF8String:className]] ;
            lua_pop(_L, 1) ;
            allGood = YES ;
        }
    } else {
        [self logAtLevel:LS_LOG_WARN
             withMessage:@"registerLuaObjectHelper:forClass: requires both helperFN and className"
            fromStackPos:level] ;
    }
    return allGood ;
}

- (BOOL)registerLuaObjectHelper:(luaObjectHelperFunction)helperFN forClass:(char *)className withUserdataMapping:(char *)userdataTag {
    BOOL allGood = [self registerLuaObjectHelper:helperFN forClass:className];
    if (allGood)
        [registeredLuaObjectHelperUserdataMappings setObject:[NSString stringWithUTF8String:className] forKey:[NSString stringWithUTF8String:userdataTag]];
    return allGood ;
}

- (NSRect)tableToRectAtIndex:(int)idx {
    if (lua_type(_L, idx) == LUA_TTABLE) {
        CGFloat x = (lua_getfield(_L, idx, "x") == LUA_TNUMBER) ? lua_tonumber(_L, -1) : 0.0 ;
        CGFloat y = (lua_getfield(_L, idx, "y") == LUA_TNUMBER) ? lua_tonumber(_L, -1) : 0.0 ;
        CGFloat w = (lua_getfield(_L, idx, "w") == LUA_TNUMBER) ? lua_tonumber(_L, -1) : 0.0 ;
        CGFloat h = (lua_getfield(_L, idx, "h") == LUA_TNUMBER) ? lua_tonumber(_L, -1) : 0.0 ;
        lua_pop(_L, 4);
        return  NSMakeRect(x, y, w, h) ;
    } else {
        [self logAtLevel:LS_LOG_WARN
             withMessage:[NSString stringWithFormat:@"returning NSZeroRect: can't make NSRect from %s.", lua_typename(_L, lua_type(_L, idx))]
            fromStackPos:1] ;
        return NSZeroRect ;
    }
}

- (NSPoint)tableToPointAtIndex:(int)idx {
    if (lua_type(_L, idx) == LUA_TTABLE) {
        CGFloat x = (lua_getfield(_L, idx, "x") == LUA_TNUMBER) ? lua_tonumber(_L, -1) : 0.0 ;
        CGFloat y = (lua_getfield(_L, idx, "y") == LUA_TNUMBER) ? lua_tonumber(_L, -1) : 0.0 ;
        lua_pop(_L, 2);
        return NSMakePoint(x, y);
    } else {
        [self logAtLevel:LS_LOG_WARN
             withMessage:[NSString stringWithFormat:@"returning NSZeroPoint: can't make NSPoint from %s.", lua_typename(_L, lua_type(_L, idx))]
            fromStackPos:1] ;
        return NSZeroPoint ;
    }
}

- (NSSize)tableToSizeAtIndex:(int)idx {
    if (lua_type(_L, idx) == LUA_TTABLE) {
        CGFloat w = (lua_getfield(_L, idx, "w") == LUA_TNUMBER) ? lua_tonumber(_L, -1) : 0.0 ;
        CGFloat h = (lua_getfield(_L, idx, "h") == LUA_TNUMBER) ? lua_tonumber(_L, -1) : 0.0 ;
        lua_pop(_L, 2);
        return NSMakeSize(w, h);
    } else {
        [self logAtLevel:LS_LOG_WARN
             withMessage:[NSString stringWithFormat:@"returning NSZeroSize: can't make NSSize from %s.", lua_typename(_L, lua_type(_L, idx))]
            fromStackPos:1] ;
        return NSZeroSize ;
    }
}

#pragma mark - Support Functions

// maxn   returns the largest integer key in the table
- (lua_Integer)maxNatIndex:(int)idx {
    lua_Integer max = 0;
    if (lua_type(_L, idx) == LUA_TTABLE) {
        lua_pushnil(_L);  /* first key */
        while (lua_next(_L, idx)) {
            lua_pop(_L, 1);  /* remove value */
            if (lua_type(_L, -1) == LUA_TNUMBER && lua_isinteger(_L, -1)) {
                lua_Integer v = lua_tointeger(_L, -1);
                if (v > max) max = v;
            }
        }
    } else {
        [self logAtLevel:LS_LOG_ERROR
             withMessage:[NSString stringWithFormat:@"table expected (found %s)", lua_typename(_L, lua_type(_L, idx))]
            fromStackPos:0] ;
    }
    return max ;
}

// countn returns the number of items of any key type in the table
- (lua_Integer)countNatIndex:(int)idx {
    lua_Integer max = 0;
    if (lua_type(_L, idx) == LUA_TTABLE) {
        lua_pushnil(_L);  /* first key */
        while (lua_next(_L, idx)) {
          lua_pop(_L, 1);  /* remove value */
          max++ ;
        }
    } else {
        [self logAtLevel:LS_LOG_ERROR
             withMessage:[NSString stringWithFormat:@"table expected (found %s)", lua_typename(_L, lua_type(_L, idx))]
            fromStackPos:0] ;
    }
    return max ;
}

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

- (NSString *)getValidUTF8AtIndex:(int)idx {
    size_t sourceLength ;
    unsigned char *src  = (unsigned char *)luaL_tolstring(_L, idx, &sourceLength) ;
    NSMutableData *dest = [[NSMutableData alloc] init] ;

    unsigned char nullChar[]    = { 0xE2, 0x88, 0x85 } ;
    unsigned char invalidChar[] = { 0xEF, 0xBF, 0xBD } ;

    size_t pos = 0 ;
    while (pos < sourceLength) {
        if (src[pos] > 0 && src[pos] <= 127) {
            [dest appendBytes:(void *)(src + pos) length:1] ; pos++ ;
        } else if ((src[pos] >= 194 && src[pos] <= 223) && (src[pos+1] >= 128 && src[pos+1] <= 191)) {
            [dest appendBytes:(void *)(src + pos) length:2] ; pos = pos + 2 ;
        } else if ((src[pos] == 224 && (src[pos+1] >= 160 && src[pos+1] <= 191) && (src[pos+2] >= 128 && src[pos+2] <= 191)) ||
                   ((src[pos] >= 225 && src[pos] <= 236) && (src[pos+1] >= 128 && src[pos+1] <= 191) && (src[pos+2] >= 128 && src[pos+2] <= 191)) ||
                   (src[pos] == 237 && (src[pos+1] >= 128 && src[pos+1] <= 159) && (src[pos+2] >= 128 && src[pos+2] <= 191)) ||
                   ((src[pos] >= 238 && src[pos] <= 239) && (src[pos+1] >= 128 && src[pos+1] <= 191) && (src[pos+2] >= 128 && src[pos+2] <= 191))) {
            [dest appendBytes:(void *)(src + pos) length:3] ; pos = pos + 3 ;
        } else if ((src[pos] == 240 && (src[pos+1] >= 144 && src[pos+1] <= 191) && (src[pos+2] >= 128 && src[pos+2] <= 191) && (src[pos+3] >= 128 && src[pos+3] <= 191)) ||
                   ((src[pos] >= 241 && src[pos] <= 243) && (src[pos+1] >= 128 && src[pos+1] <= 191) && (src[pos+2] >= 128 && src[pos+2] <= 191) && (src[pos+3] >= 128 && src[pos+3] <= 191)) ||
                   (src[pos] == 244 && (src[pos+1] >= 128 && src[pos+1] <= 143) && (src[pos+2] >= 128 && src[pos+2] <= 191) && (src[pos+3] >= 128 && src[pos+3] <= 191))) {
            [dest appendBytes:(void *)(src + pos) length:4] ; pos = pos + 4 ;
        } else {
            if (src[pos] == 0)
                [dest appendBytes:(void *)nullChar length:3] ;
            else
                [dest appendBytes:(void *)invalidChar length:3] ;
            pos = pos + 1 ;
        }
    }

    // we're done with src, so its safe to pop the stack of luaL_tolstring's value
    lua_pop(_L, 1) ;

    return [[NSString alloc] initWithData:dest encoding:NSUTF8StringEncoding] ;
}

- (BOOL)requireModule:(char *)moduleName {
    lua_getglobal(_L, "require"); lua_pushstring(_L, moduleName) ;
    return [self protectedCallAndTraceback:1 nresults:1] ;
}

#pragma mark - conversionSupport extensions to LuaSkin class

- (int)pushNSObject:(id)obj withOptions:(LS_NSConversionOptions)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
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
            [self pushNSNumber:obj withOptions:options] ;
        } else if ([obj isKindOfClass:[NSString class]]) {
                size_t size = [(NSString *)obj lengthOfBytesUsingEncoding:NSUTF8StringEncoding] ;
                lua_pushlstring(_L, [(NSString *)obj UTF8String], size) ;
        } else if ([obj isKindOfClass:[NSData class]]) {
            lua_pushlstring(_L, [(NSData *)obj bytes], [(NSData *)obj length]) ;
        } else if ([obj isKindOfClass:[NSDate class]]) {
            lua_pushinteger(_L, lround([(NSDate *)obj timeIntervalSince1970])) ;
        } else if ([obj isKindOfClass:[NSArray class]]) {
            [self pushNSArray:obj withOptions:options alreadySeenObjects:alreadySeen] ;
        } else if ([obj isKindOfClass:[NSSet class]]) {
            [self pushNSSet:obj withOptions:options alreadySeenObjects:alreadySeen] ;
        } else if ([obj isKindOfClass:[NSDictionary class]]) {
            [self pushNSDictionary:obj withOptions:options alreadySeenObjects:alreadySeen] ;
        } else if ([obj isKindOfClass:[NSURL class]]) {
// normally I'd make a class a helper registered as part of a module; however, NSURL is common enough
// and 99% of the time we just want it stringified... by putting it in here, if someone needs it to do
// more later, they can register a helper to catch the object before it reaches here.
            lua_pushstring(_L, [[obj absoluteString] UTF8String]) ;
        } else {
            if ((options & LS_NSDescribeUnknownTypes) == LS_NSDescribeUnknownTypes) {
                [self logDebug:[NSString stringWithFormat:@"unrecognized type %@; converting to '%@'", NSStringFromClass([obj class]), [obj debugDescription]]] ;
                lua_pushstring(_L, [[NSString stringWithFormat:@"%@", [obj debugDescription]] UTF8String]) ;
            } else if ((options & LS_NSIgnoreUnknownTypes) == LS_NSIgnoreUnknownTypes) {
                [self logDebug:[NSString stringWithFormat:@"unrecognized type %@; ignoring", NSStringFromClass([obj class])]] ;
                return 0 ;
            }else {
                [self logDebug:[NSString stringWithFormat:@"unrecognized type %@; returning nil", NSStringFromClass([obj class])]] ;
                lua_pushnil(_L) ;
            }
        }
    } else {
        lua_pushnil(_L) ;
    }
    return 1 ;
}

- (int)pushNSNumber:(id)obj withOptions:(LS_NSConversionOptions)options {
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
            case 'Q': if ((options & LS_NSUnsignedLongLongPreserveBits) == LS_NSUnsignedLongLongPreserveBits) {
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
                [self logDebug:[NSString stringWithFormat:@"unrecognized numerical type '%s' for '%@'", [number objCType], number]] ;
                lua_pushnumber(_L, [number doubleValue]) ;
                break ;
        }
    }
    return 1 ;
}

- (int)pushNSArray:(id)obj withOptions:(LS_NSConversionOptions)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
    NSArray* list = obj;
    lua_newtable(_L);
    [alreadySeen setObject:[NSNumber numberWithInt:luaL_ref(_L, LUA_REGISTRYINDEX)] forKey:obj] ;
    lua_rawgeti(_L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:obj] intValue]) ; // put it back on the stack
    for (id item in list) {
        int results = [self pushNSObject:item withOptions:options alreadySeenObjects:alreadySeen];
// NOTE: This isn't a true representation of the intent of LS_NSIgnoreUnknownTypes as it will actually put `nil`
// in the indexed positions... is that a problem?  Keeps the numbering indexing simple, though
        if (results == 0) lua_pushnil(_L) ;
        lua_rawseti(_L, -2, luaL_len(_L, -2) + 1) ;
    }
    return 1 ;
}

- (int)pushNSSet:(id)obj withOptions:(LS_NSConversionOptions)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
    NSSet* list = obj;
    lua_newtable(_L);
    [alreadySeen setObject:[NSNumber numberWithInt:luaL_ref(_L, LUA_REGISTRYINDEX)] forKey:obj] ;
    lua_rawgeti(_L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:obj] intValue]) ; // put it back on the stack
    for (id item in list) {
        int results = [self pushNSObject:item withOptions:options alreadySeenObjects:alreadySeen];
// NOTE: Since an NSSet is unordered anyways, we're opting for simply disregarding ignored items
        if (results > 0)
            lua_rawseti(_L, -2, luaL_len(_L, -2) + 1) ;
    }
    return 1 ;
}

- (int)pushNSDictionary:(id)obj withOptions:(LS_NSConversionOptions)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
    NSArray *keys = [obj allKeys];
    NSArray *values = [obj allValues];
    lua_newtable(_L);
    [alreadySeen setObject:[NSNumber numberWithInt:luaL_ref(_L, LUA_REGISTRYINDEX)] forKey:obj] ;
    lua_rawgeti(_L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:obj] intValue]) ; // put it back on the stack
    for (unsigned long i = 0; i < [keys count]; i++) {
        int result = [self pushNSObject:[keys objectAtIndex:i] withOptions:options alreadySeenObjects:alreadySeen];
        if (result > 0) {
            int result2 = [self pushNSObject:[values objectAtIndex:i] withOptions:options alreadySeenObjects:alreadySeen];
            if (result2 > 0) {
                lua_settable(_L, -3);
            } else {
                lua_pop(_L, 1) ; // pop the key since we won't be using it
            }
        } // else nothing was pushed on the stack, so we don't need to pop anything
    }
    return 1 ;
}

- (id)toNSObjectAtIndex:(int)idx withOptions:(LS_NSConversionOptions)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
    char *userdataTag = nil;

    int realIndex = lua_absindex(_L, idx) ;
    NSMutableArray *seenObject = [alreadySeen objectForKey:[NSValue valueWithPointer:lua_topointer(_L, idx)]] ;
    if (seenObject) {
        if ([[seenObject lastObject] isEqualToNumber:@(NO)] && ((options & LS_NSAllowsSelfReference) != LS_NSAllowsSelfReference)) {
            [self logAtLevel:LS_LOG_WARN
                 withMessage:@"lua table cannot contain self-references"
                fromStackPos:1] ;
//             return [NSNull null] ;
            return nil ;
        } else {
            return [seenObject firstObject] ;
        }
    }
    switch (lua_type(_L, realIndex)) {
        case LUA_TNUMBER:
            if (lua_isinteger(_L, idx)) {
                return @(lua_tointeger(_L, idx)) ;
            } else {
                return @(lua_tonumber(_L, idx));
            }
            break ;
        case LUA_TSTRING: {
                LS_NSConversionOptions stringOptions = options & ( LS_NSPreserveLuaStringExactly | LS_NSLuaStringAsDataOnly ) ;
                if (stringOptions == LS_NSLuaStringAsDataOnly) {
                    size_t size ;
                    unsigned char *junk = (unsigned char *)lua_tolstring(_L, idx, &size) ;
                    return [NSData dataWithBytes:(void *)junk length:size] ;
                } else if (stringOptions == LS_NSPreserveLuaStringExactly) {
                    if ([self isValidUTF8AtIndex:idx]) {
                        size_t size ;
                        unsigned char *string = (unsigned char *)lua_tolstring(_L, idx, &size) ;
                        return [[NSString alloc] initWithData:[NSData dataWithBytes:(void *)string length:size] encoding: NSUTF8StringEncoding] ;
                    } else {
                        size_t size ;
                        unsigned char *junk = (unsigned char *)lua_tolstring(_L, idx, &size) ;
                        return [NSData dataWithBytes:(void *)junk length:size] ;
                    }
                } else {
                    if (stringOptions != LS_NSNone) {
                        [self logAtLevel:LS_LOG_DEBUG
                             withMessage:@"only one of LS_NSPreserveLuaStringExactly or LS_NSLuaStringAsDataOnly can be specified: using default behavior"
                            fromStackPos:0] ;
                    }
                    return [self getValidUTF8AtIndex:idx] ;
                }
            }
            break ;
        case LUA_TNIL:
            return [NSNull null] ;
            break ;
        case LUA_TBOOLEAN:
            return lua_toboolean(_L, idx) ? (id)kCFBooleanTrue : (id)kCFBooleanFalse;
            break ;
        case LUA_TTABLE:
            return [self tableAtIndex:realIndex withOptions:options alreadySeenObjects:alreadySeen] ;
            break ;
        case LUA_TUSERDATA: // Note: This is specifically last, so it can fall through to the default case, for objects we can't handle automatically
            //FIXME: This seems very unsafe to happen outside a protected call
            if (lua_getfield(_L, realIndex, "__type") == LUA_TSTRING) {
                userdataTag = (char *)lua_tostring(_L, -1);
            }
            lua_pop(_L, 1);

            if (userdataTag) {
                NSString *classMapping = [registeredLuaObjectHelperUserdataMappings objectForKey:[NSString stringWithUTF8String:userdataTag]];
                if (classMapping) {
                    return [self luaObjectAtIndex:realIndex toClass:(char *)[classMapping UTF8String]];
                }
            }
        default:
            if ((options & LS_NSDescribeUnknownTypes) == LS_NSDescribeUnknownTypes) {
                NSString *answer = [NSString stringWithFormat:@"%s", luaL_tolstring(_L, idx, NULL)];
                [self logDebug:[NSString stringWithFormat:@"unrecognized type %s; converting to '%@'", lua_typename(_L, lua_type(_L, realIndex)), answer]] ;
                lua_pop(_L, 1) ;
                return answer ;
            } else if ((options & LS_NSIgnoreUnknownTypes) == LS_NSIgnoreUnknownTypes) {
                [self logDebug:[NSString stringWithFormat:@"unrecognized type %s; ignoring with placeholder [NSNull null]",
                                                          lua_typename(_L, lua_type(_L, realIndex))]] ;
                return [NSNull null] ;
            } else {
                [self logDebug:[NSString stringWithFormat:@"unrecognized type %s; returning nil", lua_typename(_L, lua_type(_L, realIndex))]] ;
                return nil ;
            }
            break ;
    }
}

- (id)tableAtIndex:(int)idx withOptions:(LS_NSConversionOptions)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
    id result ;

    if ([self maxNatIndex:lua_absindex(_L, idx)] == [self countNatIndex:lua_absindex(_L, idx)]) {
        result = (NSMutableArray *) [[NSMutableArray alloc] init] ;
    } else {
        result = (NSMutableDictionary *) [[NSMutableDictionary alloc] init] ;
    }
    [alreadySeen setObject:@[result, @(NO)] forKey:[NSValue valueWithPointer:lua_topointer(_L, idx)]] ;

    if ([result isKindOfClass: [NSArray class]]) {
        lua_Integer tableLength = [self countNatIndex:lua_absindex(_L, idx)] ;
        for (lua_Integer i = 0; i < tableLength ; i++) {
            lua_geti(_L, lua_absindex(_L, idx), i + 1) ;
            id val = [self toNSObjectAtIndex:-1 withOptions:options alreadySeenObjects:alreadySeen] ;
            if (val) {
                [result addObject:val] ;
                lua_pop(_L, 1) ;
            } else {
                [self logAtLevel:LS_LOG_ERROR
                     withMessage:[NSString stringWithFormat:@"array element (%s) cannot be converted into a proper NSObject",
                                                             luaL_tolstring(_L, -1, NULL)]
                    fromStackPos:1] ;
                result = nil ;
                lua_pop(_L, 2) ; // luaL_tolstring result and lua_geti result
                return nil ;
            }
        }
    } else {
        lua_pushnil(_L);
        while (lua_next(_L, lua_absindex(_L, idx)) != 0) {
            id key = [self toNSObjectAtIndex:-2             withOptions:options alreadySeenObjects:alreadySeen] ;
            id val = [self toNSObjectAtIndex:lua_gettop(_L) withOptions:options alreadySeenObjects:alreadySeen] ;
            if (key && val) {
                [result setValue:val forKey:key];
                lua_pop(_L, 1);
            } else {
                [self logAtLevel:LS_LOG_ERROR
                     withMessage:[NSString stringWithFormat:@"dictionary %@ (%s) cannot be converted into a proper NSObject",
                                                             (key) ? @"key" : @"value",
                                                             luaL_tolstring(_L, (key) ? -2 : lua_gettop(_L), NULL)]
                    fromStackPos:1] ;
                result = nil ;
                lua_pop(_L, 3) ; // luaL_tolstring result, lua_next value, and lua_next key
                return nil ;
            }
        }
    }

    [alreadySeen setObject:@[result, @(YES)] forKey:[NSValue valueWithPointer:lua_topointer(_L, idx)]] ;
    return result ;
}

#pragma mark - LuaSkin Log Support

- (void) logAtLevel:(int)level withMessage:(NSString *)theMessage {
    if (_delegate &&  [_delegate respondsToSelector:@selector(logForLuaSkinAtLevel:withMessage:)]) {
        [_delegate logForLuaSkinAtLevel:level withMessage:theMessage] ;
    } else {
        NSLog(@"(missing delegate):log level %d: %@", level, theMessage) ;
    }
}

// Testing for: chunkname:currentline:theMessage
- (void) logAtLevel:(int)level withMessage:(NSString *)theMessage fromStackPos:(int)pos {
    luaL_where(_L, pos) ;
    NSString *locationInfo = [NSString stringWithUTF8String:lua_tostring(_L, -1)] ;
    lua_pop(_L, 1) ;
    if (!locationInfo || [locationInfo isEqualToString:@""])
        locationInfo = [NSString stringWithFormat:@"(no lua location info at depth %d)", pos] ;

    [self logAtLevel:level withMessage:[NSString stringWithFormat:@"%@:%@", locationInfo, theMessage]] ;
}

// shorthand
- (void)logVerbose:(NSString *)theMessage    { [self logAtLevel:LS_LOG_VERBOSE withMessage:theMessage] ; }
- (void)logDebug:(NSString *)theMessage      { [self logAtLevel:LS_LOG_DEBUG withMessage:theMessage] ; }
- (void)logInfo:(NSString *)theMessage       { [self logAtLevel:LS_LOG_INFO withMessage:theMessage] ; }
- (void)logWarn:(NSString *)theMessage       { [self logAtLevel:LS_LOG_WARN withMessage:theMessage] ; }
- (void)logError:(NSString *)theMessage      { [self logAtLevel:LS_LOG_ERROR withMessage:theMessage] ; }
- (void)logBreadcrumb:(NSString *)theMessage { [self logAtLevel:LS_LOG_BREADCRUMB withMessage:theMessage] ; }

- (NSString *)tracebackWithTag:(NSString *)theTag fromStackPos:(int)level{
    int topIndex         = lua_gettop(_L) ;
    int absoluteIndex    = lua_absindex(_L, topIndex) ;

    luaL_traceback(_L, _L, [theTag UTF8String], level) ;
    NSString *result = [NSString stringWithFormat:@"LuaSkin Debug Traceback: top index:%d, absolute:%d\n%s",
                                                  topIndex, absoluteIndex, luaL_tolstring(_L, -1, NULL)] ;
    lua_pop(_L, 1) ;
    return result ;
}

@end
