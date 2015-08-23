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

// Well, as an extension, semi-private at least...

@interface LuaSkin (conversionSupport) // extension to LuaSkin for conversion support -- not used directly

- (int)pushNSObject:(id)obj withLocalHelpers:(pushNSHelpers*)fnList
                      preserveBitsInNSNumber:(BOOL)bitsFlag
                          alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (int)pushNSNull:(id)obj ;
- (int)pushNSNumber:(id)obj ;
- (int)pushNSNumber:(id)obj preserveBits:(BOOL)bitsOverNumber ;
- (int)pushNSString:(id)obj ;
- (int)pushNSData:(id)obj ;
- (int)pushNSDate:(id)obj ;
- (int)pushNSUnknown:(id)obj ;

- (int)pushNSArray:(id)obj withLocalHelpers:(pushNSHelpers*)fnList
                     preserveBitsInNSNumber:(BOOL)bitsFlag
                         alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (int)pushNSSet:(id)obj withLocalHelpers:(pushNSHelpers*)fnList
                   preserveBitsInNSNumber:(BOOL)bitsFlag
                       alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (int)pushNSDictionary:(id)obj withLocalHelpers:(pushNSHelpers*)fnList
                          preserveBitsInNSNumber:(BOOL)bitsFlag
                              alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;

- (id)toNSObjectFromIndex:(int)idx alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (NSNumber*)numberFromIndex:(int)idx ;
- (id)stringFromIndex:(int)idx ;
- (id)tableFromIndex:(int)idx alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (NSNumber *)booleanFromIndex:(int)idx ;
- (NSNull *)nilFromIndex:(int)idx ;
- (NSString *)unknownFromIndex:(int)idx ;

@end

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

#pragma mark - pushNSObject:object and variants

- (int)pushNSObject:(id)obj {
    return [self pushNSObject:obj preserveBitsInNSNumber:NO] ;
}

- (int)pushNSObject:(id)obj preserveBitsInNSNumber:(BOOL)bitsFlag {
    pushNSHelpers emptyList[] = {{NULL, NULL}} ;
    return [self pushNSObject:obj withLocalHelpers:emptyList preserveBitsInNSNumber:bitsFlag];
}

- (int)pushNSObject:(id)obj withLocalHelpers:(pushNSHelpers*)fnList {
    return [self pushNSObject:obj withLocalHelpers:fnList preserveBitsInNSNumber:NO] ;
}

- (int)pushNSObject:(id)obj withLocalHelpers:(pushNSHelpers*)fnList preserveBitsInNSNumber:(BOOL)bitsFlag {
    NSMutableDictionary *alreadySeen = [[NSMutableDictionary alloc] init] ;

    [self pushNSObject:obj withLocalHelpers:fnList
                     preserveBitsInNSNumber:bitsFlag
                         alreadySeenObjects:alreadySeen];
    for (id entry in alreadySeen) {
        luaL_unref(_L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:entry] intValue]) ;
    }
    return 1 ;
}

- (void)registerPushNSHelper:(pushNSHelperFunction)helperFN forClass:(char*)className {
    [registeredNSHelperFunctions setObject:[NSValue valueWithPointer:(void *)helperFN]
                                    forKey:[NSString stringWithUTF8String:className]] ;
}

- (void)unregisterPushNSHelperForClass:(char*)className {
    [registeredNSHelperFunctions removeObjectForKey:[NSString stringWithUTF8String:className]] ;
}

#pragma mark - toNSObjectFromIndex:idx and variants

- (id)toNSObjectFromIndex:(int)idx {
    NSMutableDictionary *alreadySeen = [[NSMutableDictionary alloc] init] ;

    return [self toNSObjectFromIndex:idx alreadySeenObjects:alreadySeen] ;
}

- (BOOL)isValidUTF8AtIndex:(int)idx {
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

#pragma mark - conversionSupport extensions to LuaSkin class

- (int)pushNSObject:(id)obj withLocalHelpers:(pushNSHelpers*)fnList
                      preserveBitsInNSNumber:(BOOL)bitsFlag
                          alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
// NOTE: do we also need a recursive depth?  Will crash at depth of 512... can this be caught short of a counter?
    if (obj) {

        if ([alreadySeen objectForKey:obj]) {
            lua_rawgeti(_L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:obj] intValue]) ;
            return 1 ;
        }

        // Check for run-time added converters

        for( pushNSHelpers *pos = fnList ; pos->name != NULL ; pos++) {
            if ([obj isKindOfClass: NSClassFromString([NSString stringWithUTF8String:pos->name])]) {
                return pos->func(_L, obj) ;
            }
        }

        // check for registered helpers

        for (id key in registeredNSHelperFunctions) {
            if ([obj isKindOfClass: NSClassFromString(key)]) {
                pushNSHelperFunction theFunc = (pushNSHelperFunction)[[registeredNSHelperFunctions objectForKey:key] pointerValue] ;
                return theFunc(_L, obj) ;
            }
        }

        // Check for built-in classes

        if ([obj isKindOfClass:[NSNull class]])       { return [self pushNSNull:obj] ; }
        if ([obj isKindOfClass:[NSNumber class]])     { return [self pushNSNumber:obj preserveBits:bitsFlag] ; }
        if ([obj isKindOfClass:[NSString class]])     { return [self pushNSString:obj] ; }
        if ([obj isKindOfClass:[NSData class]])       { return [self pushNSData:obj] ; }
        if ([obj isKindOfClass:[NSDate class]])       { return [self pushNSDate:obj] ; }
        if ([obj isKindOfClass:[NSArray class]])      {
            return [self pushNSArray:obj withLocalHelpers:fnList
                                   preserveBitsInNSNumber:bitsFlag
                                       alreadySeenObjects:alreadySeen] ;
        }
        if ([obj isKindOfClass:[NSSet class]])        {
            return [self pushNSSet:obj withLocalHelpers:fnList
                                 preserveBitsInNSNumber:bitsFlag
                                     alreadySeenObjects:alreadySeen] ;
        }
        if ([obj isKindOfClass:[NSDictionary class]]) {
            return [self pushNSDictionary:obj withLocalHelpers:fnList
                                        preserveBitsInNSNumber:bitsFlag
                                            alreadySeenObjects:alreadySeen] ;
        }
        if ([obj isKindOfClass:[NSObject class]])     { return [self pushNSUnknown:obj] ; }

    // shouldn't happen -- the last check, NSObject, should catch everything not yet caught.
        NSLog(@"Uncaught NSObject type for '%@'", obj) ;
        return [self pushNSUnknown:obj] ;
    } else {
        lua_pushnil(_L) ;
        return 1 ;
    }
}

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

- (int)pushNSUnknown:(id)obj {
    lua_pushstring(_L, [[NSString stringWithFormat:@"%@", obj] UTF8String]) ;
    return 1 ;
}

- (int)pushNSArray:(id)obj withLocalHelpers:(pushNSHelpers*)fnList
                     preserveBitsInNSNumber:(BOOL)bitsFlag
                         alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
    if ([obj isKindOfClass: [NSArray class]]) {
        NSArray* list = obj;
        lua_newtable(_L);
        [alreadySeen setObject:[NSNumber numberWithInt:luaL_ref(_L, LUA_REGISTRYINDEX)] forKey:obj] ;
        lua_rawgeti(_L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:obj] intValue]) ; // put it back on the stack
        for (id item in list) {
            [self pushNSObject:item withLocalHelpers:fnList
                              preserveBitsInNSNumber:bitsFlag
                                  alreadySeenObjects:alreadySeen];
            lua_rawseti(_L, -2, luaL_len(_L, -2) + 1) ;
        }
    } else {
        lua_pushnil(_L) ; // Not an NSArray
    }
    return 1 ;
}

- (int)pushNSSet:(id)obj withLocalHelpers:(pushNSHelpers*)fnList
                   preserveBitsInNSNumber:(BOOL)bitsFlag
                       alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
    if ([obj isKindOfClass: [NSSet class]]) {
        NSSet* list = obj;
        lua_newtable(_L);
        [alreadySeen setObject:[NSNumber numberWithInt:luaL_ref(_L, LUA_REGISTRYINDEX)] forKey:obj] ;
        lua_rawgeti(_L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:obj] intValue]) ; // put it back on the stack
        for (id item in list) {
            [self pushNSObject:item withLocalHelpers:fnList
                              preserveBitsInNSNumber:bitsFlag
                                  alreadySeenObjects:alreadySeen];
            lua_rawseti(_L, -2, luaL_len(_L, -2) + 1) ;
        }
    } else {
        lua_pushnil(_L) ; // Not an NSSet
    }
    return 1 ;
}

- (int)pushNSDictionary:(id)obj withLocalHelpers:(pushNSHelpers*)fnList
                   preserveBitsInNSNumber:(BOOL)bitsFlag
                       alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
    if ([obj isKindOfClass: [NSDictionary class]]) {
        NSArray *keys = [obj allKeys];
        NSArray *values = [obj allValues];
        lua_newtable(_L);
        [alreadySeen setObject:[NSNumber numberWithInt:luaL_ref(_L, LUA_REGISTRYINDEX)] forKey:obj] ;
        lua_rawgeti(_L, LUA_REGISTRYINDEX, [[alreadySeen objectForKey:obj] intValue]) ; // put it back on the stack
        for (unsigned long i = 0; i < [keys count]; i++) {
            [self pushNSObject:[keys objectAtIndex:i] withLocalHelpers:fnList
                                                preserveBitsInNSNumber:bitsFlag
                                                    alreadySeenObjects:alreadySeen];
            [self pushNSObject:[values objectAtIndex:i] withLocalHelpers:fnList
                                                  preserveBitsInNSNumber:bitsFlag
                                                      alreadySeenObjects:alreadySeen];
            lua_settable(_L, -3);
        }
    } else {
        lua_pushnil(_L) ; // Not an NSDictionary
    }
    return 1 ;
}

- (id)toNSObjectFromIndex:(int)idx
       alreadySeenObjects:(NSMutableDictionary *)alreadySeen {

    int realIndex = lua_absindex(_L, idx) ;
    if ([alreadySeen objectForKey:[NSValue valueWithPointer:lua_topointer(_L, idx)]]) {
        return [alreadySeen objectForKey:[NSValue valueWithPointer:lua_topointer(_L, idx)]] ;
    }
    switch (lua_type(_L, realIndex)) {
        case LUA_TNUMBER:
            return [self numberFromIndex:realIndex] ;
            break ;
        case LUA_TSTRING:
            return [self stringFromIndex:realIndex] ;
            break ;
        case LUA_TNIL:
            return [self nilFromIndex:realIndex] ;
            break ;
        case LUA_TBOOLEAN:
            return [self booleanFromIndex:realIndex] ;
            break ;
        case LUA_TTABLE:
            return [self tableFromIndex:realIndex alreadySeenObjects:alreadySeen] ;
            break ;
        default:
            return [self unknownFromIndex:(realIndex)] ;
            break ;
    }
}

- (NSNumber*)numberFromIndex:(int)idx {
    if (lua_isinteger(_L, idx))
        return @(lua_tointeger(_L, idx)) ;
    else
        return @(lua_tonumber(_L, idx));
}

- (id)stringFromIndex:(int)idx {
    if ([self isValidUTF8AtIndex:idx]) {
        return [NSString stringWithUTF8String:(char *)lua_tostring(_L, idx)];
    } else {
        size_t size ;
        unsigned char *junk = (unsigned char *)lua_tolstring(_L, idx, &size) ;
        return [NSData dataWithBytes:(void *)junk length:size] ;
    }
}

- (id)tableFromIndex:(int)idx
  alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
    id result ;

    if (maxn(_L, lua_absindex(_L, idx)) == countn(_L, lua_absindex(_L, idx))) {
        result = (NSMutableArray *) [[NSMutableArray alloc] init] ;
    } else {
        result = (NSMutableDictionary *) [[NSMutableDictionary alloc] init] ;
    }
    [alreadySeen setObject:result forKey:[NSValue valueWithPointer:lua_topointer(_L, idx)]] ;

    if ([result isKindOfClass: [NSArray class]]) {
        lua_Integer tableLength = countn(_L, lua_absindex(_L, idx)) ;
        for (lua_Integer i = 0; i < tableLength ; i++) {
            lua_geti(_L, lua_absindex(_L, idx), i + 1) ;
            id val = [self toNSObjectFromIndex:-1 alreadySeenObjects:alreadySeen] ;
            [result addObject:val] ;
            lua_pop(_L, 1) ;
        }
    } else {
        lua_pushnil(_L);
        while (lua_next(_L, lua_absindex(_L, idx)) != 0) {
            id key = [self toNSObjectFromIndex:-2 alreadySeenObjects:alreadySeen] ;
            id val = [self toNSObjectFromIndex:lua_gettop(_L) alreadySeenObjects:alreadySeen] ;
            [result setValue:val forKey:key];
            lua_pop(_L, 1);
        }
    }

    return result ;
}

- (NSNumber *)booleanFromIndex:(int)idx {
    return lua_toboolean(_L, idx) ? (id)kCFBooleanTrue : (id)kCFBooleanFalse;
}

- (NSNull *)nilFromIndex:(__unused int)idx {
    return [NSNull null] ;
}

- (NSString *)unknownFromIndex:(int)idx {
    return [NSString stringWithFormat:@"%s: %p", luaL_typename(_L, idx), lua_topointer(_L, idx)];
}

@end
