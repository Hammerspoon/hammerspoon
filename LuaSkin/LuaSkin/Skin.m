//
//  Skin.m
//  LuaSkin
//
//  Created by Chris Jones on 11/06/2015.
//  Copyright (c) 2015 Hammerspoon Project Authors. All rights reserved.
//

#import "Skin.h"

const char * const LuaSkin_UD_TAG = "luaskin.objectWrapper" ;

typedef struct pushNSHelpers {
    const char            *name;
    pushNSHelperFunction  func;
} pushNSHelpers;

typedef struct luaObjectHelpers {
    const char          *name ;
    luaObjectHelperFunction func ;
} luaObjectHelpers ;

#pragma mark - C-Support Functions

static int pushUserdataType(lua_State *L) {
    // safer than just checking in LuaSkin because we can call this function via pcall
    // so a userdata without an __index metafield won't cause a Lua error
    if (lua_getfield(L, 1, "__type") != LUA_TSTRING) {
        lua_pop(L, 1) ;
        lua_pushnil(L) ; // only a string is allowed to return, everything else is nil
    }
    return 1;
}

NSString *specMaskToString(int spec) {
    NSMutableArray *parts = [NSMutableArray array];

    if (spec & LS_TNIL) {
        [parts addObject:@"nil"];
    }
    if (spec & LS_TANY) {
        [parts addObject:@"anything"];
    }
    if (spec & LS_TTABLE) {
        [parts addObject:@"table"];
    }
    if (spec & LS_TNUMBER) {
        [parts addObject:@"number"];
    }
    if (spec & LS_TINTEGER) {
        [parts addObject:@"integer"];
    }
    if (spec & LS_TFUNCTION) {
        [parts addObject:@"function"];
    }
    if (spec & LS_TSTRING) {
        [parts addObject:@"string"];
    }
    if (spec & LS_TUSERDATA) {
        [parts addObject:@"userdata"];
    }
    if (spec & LS_TBOOLEAN) {
        [parts addObject:@"boolean"];
    }
    if (spec & LS_TWRAPPEDOBJECT) {
        [parts addObject:@"wrappedObject"] ;
    }

    return [parts componentsJoinedByString:@" or "];
}

static NSString *getCallerFileName(void) {
    NSString *executablePath  = [[NSBundle mainBundle] executablePath] ;
    Dl_info  libraryInfo ;
    NSArray  *csa = [NSThread callStackReturnAddresses] ;
    NSString *fname, *prevFname ;
    for (NSNumber *entry in csa) {
        prevFname = fname ;
        fname = nil ;
        uintptr_t add = entry.unsignedLongValue ;
        if (dladdr((const void *)add, &libraryInfo) != 0) {
            fname = [NSString stringWithUTF8String:libraryInfo.dli_fname] ;
            if ([fname isEqualToString:executablePath]) {
                fname = prevFname ;
                break ;
            }
            if (![fname containsString:@"LuaSkin"]) break ;
        }
    }
    return fname ;
}

// Extension to LuaSkin class to allow private modification of the lua_State property
@interface LuaSkin ()

@property (class, readwrite, assign, atomic) lua_State *mainLuaState ;
@property (class, readonly, atomic) LuaSkin *sharedLuaSkin ;

@property (class, readonly, atomic) NSMutableSet *sharedWarnings ;

@property (readwrite, assign, atomic) lua_State *L;
@property (readonly, atomic)  NSMutableDictionary *registeredNSHelperFunctions ;
@property (readonly, atomic)  NSMutableDictionary *registeredNSHelperLocations ;
@property (readonly, atomic)  NSMutableDictionary *registeredLuaObjectHelperFunctions ;
@property (readonly, atomic)  NSMutableDictionary *registeredLuaObjectHelperLocations ;
@property (readonly, atomic)  NSMutableDictionary *registeredLuaObjectHelperUserdataMappings;
@property (readonly, atomic)  NSMutableDictionary *registeredLuaObjectHelperTableMappings;
@property (readonly, atomic)  NSMutableDictionary *retainedObjectsRefTableMappings ;

@property (readwrite, assign, atomic) int debugLibraryRef ;
@end

// Extension to LuaSkin class for conversion support
@interface LuaSkin (conversionSupport)

// internal methods for pushNSObject
- (int)pushNSObject:(id)obj     withOptions:(NSUInteger)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (int)pushNSNumber:(id)obj     withOptions:(NSUInteger)options ;
- (int)pushNSArray:(id)obj      withOptions:(NSUInteger)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (int)pushNSSet:(id)obj        withOptions:(NSUInteger)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (int)pushNSDictionary:(id)obj withOptions:(NSUInteger)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (int)pushNSValue:(id)obj      withOptions:(NSUInteger)options ;

// internal methods for toNSObjectAtIndex
- (id)toNSObjectAtIndex:(int)idx withOptions:(NSUInteger)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen ;
- (id)tableAtIndex:(int)idx      withOptions:(NSUInteger)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen;
- (id)tableAtIndex:(int)idx      withLabel:(const char *)tableTag withOptions:(NSUInteger)options ;

@end

@implementation LuaSkin

// class properties do not get synthesized by the compiler...
static lua_State *_mainLuaState ;

+ (lua_State *)mainLuaState {
    return _mainLuaState ;
}

+ (void)setMainLuaState:(lua_State *)newL {
    _mainLuaState = newL ;
}

static LuaSkin *_sharedLuaSkin ;

+ (LuaSkin *)sharedLuaSkin {
    return _sharedLuaSkin ;
}

#pragma mark - Class lifecycle

static NSMutableSet *_sharedWarnings ;

+ (NSMutableSet *)sharedWarnings { return _sharedWarnings ; }

+ (id)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedWarnings = [NSMutableSet set] ;
    });

    // self in a class method == the class itself
    LuaSkin *skin = [self sharedWithState:NULL] ;

    NSString  *fname = getCallerFileName() ;

    if (fname) {
        if (![_sharedWarnings containsObject:fname]) {
            [LuaSkin logWarn:[NSString stringWithFormat:@"Deprecated LuaSkin method [LuaSkin shared] invoked by `%@`. Please notify developer of module to upgrade as this method is unsafe for use with coroutines and may disappear in a future Hammerspoon release.", fname]] ;
            [_sharedWarnings addObject:fname] ;
        }
    } else {
        [LuaSkin logWarn:@"Deprecated LuaSkin method [LuaSkin shared] invoked but unable to determine source library. Notify Hammerspoon developers and include the following stack trace:"] ;
        [LuaSkin logWarn:[[NSThread callStackSymbols] componentsJoinedByString:@"\r"]] ;
    }

    return skin ;
}

+ (id)sharedWithState:(lua_State *)L {
    // self in a class method == the class itself
    LuaSkin *skin = [self sharedWithDelegate:nil] ;
    if (L) {
        if (lua_status(L) != LUA_OK) {
            NSLog(@"GRAVE BUG: LUASKIN ATTEMPTING TO USE SUSPENDED OR DEAD LUATHREAD");
            for (NSString *stackSymbol in [NSThread callStackSymbols]) {
                NSLog(@"Previous stack symbol: %@", stackSymbol);
            }
            NSException* myException = [NSException
                                        exceptionWithName:@"LuaThreadNotOk"
                                        reason:@"LuaSkin can only function on an active lua thread"
                                        userInfo:nil];
            @throw myException;
        } else {
            skin.L = L ;
        }
    } else {
        skin.L = _mainLuaState ;
    }
    return skin ;
}

+ (id)sharedWithDelegate:(id)delegate {
//     static LuaSkin *sharedLuaSkin = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedLuaSkin = [[self alloc] initWithDelegate:delegate];
    });
    if (![NSThread isMainThread]) {
        NSLog(@"GRAVE BUG: LUA EXECUTION ON NON_MAIN THREAD");
        for (NSString *stackSymbol in [NSThread callStackSymbols]) {
            NSLog(@"Previous stack symbol: %@", stackSymbol);
        }
        NSException* myException = [NSException
                                    exceptionWithName:@"LuaOnNonMainThread"
                                    reason:@"Lua execution is happening on a non-main thread"
                                    userInfo:nil];
        @throw myException;
    }
#if 0
    NSLog(@"LuaSkin:shared stack size: %d", lua_gettop(_sharedLuaSkin.L));
#endif

    _sharedLuaSkin.L = _mainLuaState ;
    return _sharedLuaSkin;
}

- (id)init {
    return [self initWithDelegate:nil];
}

- (id)initWithDelegate:(id)delegate {
    self = [super init];
    if (self) {
        _L = NULL;
        _registeredNSHelperFunctions               = [[NSMutableDictionary alloc] init] ;
        _registeredNSHelperLocations               = [[NSMutableDictionary alloc] init] ;
        _registeredLuaObjectHelperFunctions        = [[NSMutableDictionary alloc] init] ;
        _registeredLuaObjectHelperLocations        = [[NSMutableDictionary alloc] init] ;
        _registeredLuaObjectHelperUserdataMappings = [[NSMutableDictionary alloc] init];
        _registeredLuaObjectHelperTableMappings    = [[NSMutableDictionary alloc] init];
        _retainedObjectsRefTableMappings           = [[NSMutableDictionary alloc] init];

        // Set the delegate before even instantiating Lua so we capture all logging attempts.
        if (delegate) {
            self.delegate = delegate;
        }

        [self createLuaState];
    }
    return self;
}

#pragma mark - lua_State lifecycle

- (void)createLuaState {
    NSString *catastropheText = @"";

    NSLog(@"createLuaState");
    NSAssert((LuaSkin.mainLuaState == NULL), @"createLuaState called on a live Lua environment", nil);
    self.uuid = [NSUUID UUID];
    [self logBreadcrumb:[NSString stringWithFormat:@"createLuaState: %@", self.uuid]];

    LuaSkin.mainLuaState = luaL_newstate();
    luaL_openlibs(LuaSkin.mainLuaState);

    lua_getglobal(LuaSkin.mainLuaState, "debug") ;
    self.debugLibraryRef = luaL_ref(LuaSkin.mainLuaState, LUA_REGISTRYINDEX) ;

    NSString *luaSkinLua = [[NSBundle bundleForClass:[self class]] pathForResource:@"luaskin" ofType:@"lua"];
    if (!luaSkinLua) {
        catastropheText = @"createLuaState was unable to find luaskin.lua. Please re-install Hammerspoon";
        goto catastrophe;
    }

    luaopen_luaskin_internal(LuaSkin.mainLuaState) ; // load objectWrapper userdata methods and create _G["ls"]

    int loadresult = luaL_loadfile(LuaSkin.mainLuaState, luaSkinLua.fileSystemRepresentation); // extend _G["ls"]
    if (loadresult != 0) {
        catastropheText = @"createLuaState was unable to load luaskin.lua. Please re-install Hammerspoon";
        goto catastrophe;
    }

    int luaresult = lua_pcall(LuaSkin.mainLuaState, 0, 0, 0);
    if (luaresult != LUA_OK) {
        catastropheText = @"createLuaState was unable to evaluate luaskin.lua. Please re-install Hammerspoon";
        goto catastrophe;
    }

    return;

catastrophe:
    [self.delegate handleCatastrophe:catastropheText];
    exit(1);
}

- (void)destroyLuaState {
    [self logBreadcrumb:[NSString stringWithFormat:@"destroyLuaState: %@", self.uuid]];
    NSAssert((LuaSkin.mainLuaState != NULL), @"destroyLuaState called with no Lua environment", nil);
    if (LuaSkin.mainLuaState) {
        [self.retainedObjectsRefTableMappings enumerateKeysAndObjectsUsingBlock:^(NSNumber *refTableN, NSMutableDictionary *objectMappings, __unused BOOL *stop) {
            if ([refTableN isKindOfClass:[NSNumber class]] && [objectMappings isKindOfClass:[NSDictionary class]]) {
                int tmpRefTable = refTableN.intValue ;
                for (id object in objectMappings.allValues) [self luaRelease:tmpRefTable forNSObject:object] ;

            } else {
                [self logBreadcrumb:[NSString stringWithFormat:@"destroyLuaState - invalid retainedObject reference table entry: %@ = %@", refTableN, objectMappings]];
            }
        }] ;
        [self.retainedObjectsRefTableMappings           removeAllObjects] ;

        luaL_unref(LuaSkin.mainLuaState, LUA_REGISTRYINDEX, self.debugLibraryRef) ;
        self.debugLibraryRef = LUA_REFNIL ;

        lua_close(LuaSkin.mainLuaState);
        [self.registeredNSHelperFunctions               removeAllObjects] ;
        [self.registeredNSHelperLocations               removeAllObjects] ;
        [self.registeredLuaObjectHelperFunctions        removeAllObjects] ;
        [self.registeredLuaObjectHelperLocations        removeAllObjects] ;
        [self.registeredLuaObjectHelperUserdataMappings removeAllObjects];
        [self.registeredLuaObjectHelperTableMappings    removeAllObjects];
    }
    if (self.L) {
        self.L = NULL;
    }
    LuaSkin.mainLuaState = NULL;
}

- (void)resetLuaState {
    NSLog(@"resetLuaState");
    NSAssert((LuaSkin.mainLuaState != NULL), @"resetLuaState called with no Lua environment", nil);
    [self destroyLuaState];
    [self createLuaState];
}

- (BOOL)checkGCCanary:(LSGCCanary)canary {
    if (!self.L) {
        [self logBreadcrumb:@"LuaSkin nil lua_State detected"];
        return NO;
    }

    NSString *NSlsCanary = [NSString stringWithCString:canary.uuid encoding:NSUTF8StringEncoding];
    if (!NSlsCanary || ![self.uuid.UUIDString isEqualToString:NSlsCanary]) {
        [self logWarn:@"LuaSkin has caught an attempt to operate on an object that has been garbage collected."];
        return NO;
    }

    return YES;
}

- (LSGCCanary)createGCCanary {
    LSGCCanary canary;
    memset(canary.uuid, 0, LSUUIDLen);
    strncpy(canary.uuid, "UNINITIALISED", 13);

    const char *tmpUUID = [self.uuid.UUIDString cStringUsingEncoding:NSUTF8StringEncoding];
    if (tmpUUID) {
        strncpy(canary.uuid, tmpUUID, LSUUIDLen);
    }

    return canary;
}

- (void)destroyGCCanary:(LSGCCanary *)canary {
    memset(canary->uuid, 0, LSUUIDLen);
    strncpy(canary->uuid, "GC", 2);
}

#pragma mark - Methods for calling into Lua from C

- (BOOL)protectedCallAndTraceback:(int)nargs nresults:(int)nresults {
    // At this point we are being called with nargs+1 items on the stack, but we need to shove our traceback handler below that

    // Get debug.traceback() onto the top of the stack
    lua_rawgeti(self.L, LUA_REGISTRYINDEX, self.debugLibraryRef);
    lua_getfield(self.L, -1, "traceback");
    lua_remove(self.L, -2);

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
    lua_insert(self.L, tracebackPosition);

    // if we call something that resumed a coroutine, we can't be positive what self.L points to
    lua_State *backup = self.L ;
    int status = lua_pcall(self.L, nargs, nresults, tracebackPosition) ;
    self.L = backup ;

    if (status != LUA_OK) {
        lua_remove(self.L, -2) ; // remove the message handler
        // At this point the error message from lua_pcall() is on the stack. Our caller is required to deal with this.
        return NO;
    }

    lua_remove(self.L, -nresults - 1) ; // remove the message handler
    return YES;
}

- (BOOL)protectedCallAndError:(NSString*)message nargs:(int)nargs nresults:(int)nresults {
    BOOL result = [self protectedCallAndTraceback:nargs nresults:nresults];
    if (result == NO) {
        [self logError:[NSString stringWithFormat:@"%@: %s", message, lua_tostring(self.L, -1)]];
        lua_pop(self.L, 1);
    }
    return result;
}

#pragma mark - Methods for registering libraries with Lua

- (LSRefTable)registerLibrary:(const luaL_Reg *)functions metaFunctions:(const luaL_Reg *)metaFunctions {
    [self logWarn:@"This library is using an old registerLibrary method on LuaSkin"];
    return [self registerLibrary:"Unknown" functions:functions metaFunctions:metaFunctions];
}

- (LSRefTable)registerLibrary:(const char * _Nonnull)libraryName functions:(const luaL_Reg *)functions metaFunctions:(const luaL_Reg *)metaFunctions {

    NSAssert(libraryName != NULL, @"libraryName can not be NULL", nil);
    // Ensure we're not given a null function table
    NSAssert(functions != NULL, @"functions can not be NULL", nil);

    // Ensure that none of the functions we've been given are null
    const luaL_Reg *l = functions;
    for (; l->name != NULL; l++) {
        NSAssert(l->func != NULL, @"registerLibrary given a null function pointer for %s", l->name);
    }

    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:3 withMessage:"registerLibrary"];

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wconstant-conversion"
#pragma GCC diagnostic ignored "-Wunknown-warning-option"
#pragma GCC diagnostic ignored "-Wsizeof-pointer-div"
    luaL_newlib(self.L, functions);
    if (metaFunctions != nil) {
        luaL_newlib(self.L, metaFunctions);
#pragma GCC diagnostic pop
        lua_setmetatable(self.L, -2);
    }
    lua_newtable(self.L);

    NSString *fname = getCallerFileName() ;

    // FIXME: Can this all be replaced just by using the libraryName argument?
    if (fname) {
        NSRange range = [fname rangeOfString:@"/hs/"] ;
        if (range.location == NSNotFound) range = [fname rangeOfString:@"/LuaSkin"] ;
        if (range.location != NSNotFound) {
            NSUInteger startAt = range.location + 1 ;
            if (startAt < fname.length) {
                fname = [fname substringFromIndex:startAt] ;
            }
            if ([fname hasSuffix:@".so"]) fname = [fname substringToIndex:(fname.length - 3)] ;
            fname = [fname stringByReplacingOccurrencesOfString:@"/" withString:@"."] ;
        }
        lua_pushstring(self.L, fname.UTF8String) ;
    } else {
        lua_pushstring(self.L, "** unable to determine source file **" ) ;
    }
    lua_setfield(self.L, -2, "__type") ;

    int tmpRefTable = luaL_ref(self.L, LUA_REGISTRYINDEX);
    NSAssert(tmpRefTable != LUA_REFNIL, @"Unexpected LUA_REFNIL registering library: %@", fname);

    lua_pushinteger(self.L, tmpRefTable) ;
    lua_setfield(self.L, -2, "__refTable") ;
    return tmpRefTable;
}

- (LSRefTable)registerLibraryWithObject:(const char *)libraryName functions:(const luaL_Reg *)functions metaFunctions:(const luaL_Reg *)metaFunctions objectFunctions:(const luaL_Reg *)objectFunctions {

    NSAssert(libraryName != NULL, @"libraryName can not be NULL", nil);
    NSAssert(functions != NULL, @"functions can not be NULL (%s)", libraryName);
    NSAssert(objectFunctions != NULL, @"objectFunctions can not be NULL (%s)", libraryName);

    [self registerObject:libraryName objectFunctions:objectFunctions];

    return [self registerLibrary:libraryName functions:functions metaFunctions:metaFunctions];
}

- (void)registerObject:(const char *)objectName objectFunctions:(const luaL_Reg *)objectFunctions {
    NSAssert(objectName != NULL, @"objectName can not be NULL", nil);
    NSAssert(objectFunctions != NULL, @"objectFunctions can not be NULL (%s)", objectName);

    // Ensure that none of the functions we've been given are null
    const luaL_Reg *l = objectFunctions;
    for (; l->name != NULL; l++) {
        NSAssert(l->func != NULL, @"registerObject given a null function pointer for %s:%s", objectName, l->name);
    }

    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:2 withMessage:"registerObject"];

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wconstant-conversion"
#pragma GCC diagnostic ignored "-Wunknown-warning-option"
#pragma GCC diagnostic ignored "-Wsizeof-pointer-div"
    luaL_newlib(self.L, objectFunctions);
#pragma GCC diagnostic pop
    lua_pushvalue(self.L, -1);
    lua_setfield(self.L, -2, "__index");
    lua_pushstring(self.L, objectName);
    lua_setfield(self.L, -2, "__type");
    // used by some error functions in Lua
    lua_pushstring(self.L, objectName);
    lua_setfield(self.L, -2, "__name");
    lua_setfield(self.L, LUA_REGISTRYINDEX, objectName);
}

- (int)luaRef:(int)refTable {
    NSAssert((refTable != LUA_NOREF && refTable != LUA_REFNIL), @"ERROR: LuaSkin::luaRef was passed a NOREF/REFNIL refTable", nil);

    if (lua_isnil(self.L, -1)) {
        // Remove the nil from the stack
        lua_remove(self.L, -1);

        return LUA_REFNIL;
    }

    int ref = LUA_NOREF;

    if (refTable == LUA_REGISTRYINDEX) {
        // Directly store the value in the global registry
        ref = luaL_ref(self.L, LUA_REGISTRYINDEX);
        return ref;
    }

    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:1 withMessage:"luaRef:"];

    // Push refTable onto the stack
    lua_rawgeti(self.L, LUA_REGISTRYINDEX, refTable);

    // Move refTable to second on the stack, underneath the object to reference
    lua_insert(self.L, -2);

    // Reference the object at the top of the stack (pops it off)
    ref = luaL_ref(self.L, -2);

    // Remove refTable from the stack
    lua_remove(self.L, -1);

    return ref;
}

- (int)luaRef:(int)refTable atIndex:(int)idx {
    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:1 withMessage:"luaRef:atIndex"];
    lua_pushvalue(self.L, idx);
    return [self luaRef:refTable];
}

- (int)luaUnref:(int)refTable ref:(int)ref {
    NSAssert((refTable != LUA_NOREF && refTable != LUA_REFNIL), @"ERROR: LuaSkin::luaUnref was passed a NOREF/REFNIL refTable", nil);

    if (refTable == LUA_REGISTRYINDEX && ref != LUA_NOREF && ref != LUA_REFNIL) {
        luaL_unref(self.L, LUA_REGISTRYINDEX, ref);
        return LUA_NOREF;
    }

    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:1 withMessage:"luaUnref"];

    if (ref != LUA_NOREF && ref != LUA_REFNIL) {
        // Push refTable onto the stack
        lua_rawgeti(self.L, LUA_REGISTRYINDEX, refTable);

        // Dereference the supplied ref, from refTable
        luaL_unref(self.L, -1, ref);

        // Remove refTable from the stack
        lua_remove(self.L, -1);
    }
    return LUA_NOREF;
}

- (int)pushLuaRef:(int)refTable ref:(int)ref {
    NSAssert((refTable != LUA_NOREF && refTable != LUA_REFNIL), @"ERROR: LuaSkin::pushLuaRef was passed a NOREF/REFNIL refTable", nil);
    NSAssert((ref != LUA_NOREF && ref != LUA_REFNIL), @"ERROR: LuaSkin::pushLuaRef was passed a NOREF/REFNIL ref", nil);

    int type = LUA_TNONE;

    if (refTable == LUA_REGISTRYINDEX) {
        type = lua_rawgeti(self.L, LUA_REGISTRYINDEX, ref);
        return type;
    }

    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:2 withMessage:"pushLuaRef"];

    // Push refTable onto the stack
    lua_rawgeti(self.L, LUA_REGISTRYINDEX, refTable);

    // Push ref onto the stack
    type = lua_rawgeti(self.L, -1, ref);

    // Remove refTable from the stack
    lua_remove(self.L, -2);

    return type;
}

- (BOOL)checkRefs:(int)firstRef, ... {
    BOOL result = YES;
    int ref = firstRef;

    va_list args;
    va_start(args, firstRef);

    while (true) {
        if (ref == LS_RBREAK) {
            break;
        }
        if (ref == LUA_REFNIL || ref == LUA_NOREF) {
            result = NO;
            break;
        }
        ref = va_arg(args, int);
    }

    return result;
}

- (void)checkArgs:(int)firstArg, ... {
    int idx = 1;
    int numArgs = lua_gettop(self.L);
    int spec = firstArg;
    int lsType = -1;

    va_list args;
    va_start(args, firstArg);

    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:2 withMessage:"checkArgs"];

    while (true) {
        if (spec & LS_TBREAK) {
            idx--;
            break;
        }

        int luaType = lua_type(self.L, idx);
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
//                 lsType = LS_TNONE;
//                // FIXME: should there be a break here? If not, document why not
//
// I think the reason is this:
//
// if it was none because of an optional argument, we've already jumped out of this.  Otherwise,
// this really should generate a missing argument error; since Lua's error routines indicate nil
// when an expected argument isn't specified, fall through to LUA_TNIL...
            case LUA_TNIL:
                lsType = LS_TNIL;
                break;
            case LUA_TBOOLEAN:
                lsType = LS_TBOOLEAN;
                break;
            case LUA_TNUMBER:
                lsType = LS_TNUMBER;

                if ((spec & lsType) && (spec & LS_TINTEGER)) {
                    int isInteger ;
                    lua_tointegerx(self.L, idx, &isInteger) ;
                    if (!isInteger) {
                        luaL_error(self.L, "ERROR: number must be an integer for argument %d", idx) ;
                    }
                }

                break;
            case LUA_TSTRING:
                lsType = LS_TSTRING;
                break;
            case LUA_TFUNCTION:
                lsType = LS_TFUNCTION;
                break;
            case LUA_TTABLE:
                if (spec & LS_TTYPEDTABLE) {
                    lsType = LS_TTYPEDTABLE;
                    char *expectedTableTag = va_arg(args, char*);
                    if (!expectedTableTag) {
                        luaL_error(self.L, "ERROR: unable to get expected LuaSkin table type for argument %d", idx) ;
                        return; // This is useless since luaL_error() never returns, but this makes clang's analyser happier
                    }

                    const char *actualTableTag   = NULL ;
                    if (lua_getfield(self.L, idx, "__luaSkinType") == LUA_TSTRING) {
                        actualTableTag = lua_tostring(self.L, -1) ;
                    }
                    lua_pop(self.L, 1) ;
                    if (!actualTableTag || !(strcmp(actualTableTag, expectedTableTag) == 0)) {
                        luaL_error(self.L, "ERROR: incorrect LuaSkin typed table for argument %d (expected %s)", idx, expectedTableTag) ;
                    }
                } else if (spec & LS_TFUNCTION) {
                // they want a function, so let's see if this table can mimic a function
                    if (luaL_getmetafield(self.L, idx, "__call") != LUA_TNIL) {
                        lua_pop(self.L, 1) ;
                        lsType = LS_TFUNCTION ;
                    } else {
                // no, so allow normal error handling to catch this
                        lsType = LS_TTABLE ;
                    }
                } else {
                    lsType = LS_TTABLE;
                }
                break;
            case LUA_TUSERDATA:
                lsType = LS_TUSERDATA;

                if (spec & LS_TWRAPPEDOBJECT) {
                    if (!luaL_testudata(self.L, idx, LuaSkin_UD_TAG)) {
                        luaL_error(self.L, "ERROR: incorrect userdata type for argument %d (expected %s)", idx, LuaSkin_UD_TAG);
                    }
                } else {
                    // We have to duplicate this check here, because if the user wasn't supposed to pass userdata, we won't have a valid userdataTag value available
                    if (!(spec & lsType)) {
                        luaL_error(self.L, "ERROR:  incorrect type '%s' for argument %d (expected %s)", luaL_typename(self.L, idx), idx, specMaskToString(spec).UTF8String);
                    }

                    userdataTag = va_arg(args, char*);
                    if (!userdataTag || strlen(userdataTag) == 0 || !luaL_testudata(self.L, idx, userdataTag)) {
                        luaL_error(self.L, "ERROR: incorrect userdata type for argument %d (expected %s)", idx, userdataTag);
                    }
                }
                break;

            default:
                luaL_error(self.L, "ERROR: unknown type '%s' for argument %d", luaL_typename(self.L, idx), idx);
                break;
        }

        if (!(spec & LS_TANY) && !(spec & lsType) && !(spec & LS_TWRAPPEDOBJECT)) {
            luaL_error(self.L, "ERROR: incorrect type '%s' for argument %d (expected %s)", luaL_typename(self.L, idx), idx, specMaskToString(spec).UTF8String);
        }
nextarg:
        spec = va_arg(args, int);
        idx++;
    }
    va_end(args);

    if (!(spec & LS_TVARARG)) {
        if (idx != numArgs) {
            luaL_error(self.L, "ERROR: incorrect number of arguments. Expected %d, got %d", idx, numArgs);
        }
    }
}

- (int)luaTypeAtIndex:(int)idx {
    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:1 withMessage:"luaTypeAtIndex"];

    int foundType = lua_type(self.L, idx) ;
    if (foundType == LUA_TTABLE) {
        if (luaL_getmetafield(self.L, idx, "__call") != LUA_TNIL) {
            lua_pop(self.L, 1) ;
            foundType = LUA_TFUNCTION ;
        }
    }
    return foundType ;
}

- (BOOL)luaRetain:(int)refTable forNSObject:(id)object {
    if (![self canPushNSObject:object]) return NO ;
    if (!self.retainedObjectsRefTableMappings[@(refTable)])
            self.retainedObjectsRefTableMappings[@(refTable)] = [[NSMutableDictionary alloc] init] ;
    NSMutableDictionary *holding = self.retainedObjectsRefTableMappings[@(refTable)] ;
    [self pushNSObject:object] ;
    int newRef = [self luaRef:refTable] ;
    holding[@(newRef)] = object ;
    return YES ;
}

- (void)luaRelease:(int)refTable forNSObject:(id)object {
    if (![self canPushNSObject:object]) return ;
    if (!self.retainedObjectsRefTableMappings[@(refTable)]) return ;
    NSMutableDictionary *holding = self.retainedObjectsRefTableMappings[@(refTable)] ;
    NSArray             *refs    = [holding allKeysForObject:object] ;
    if (refs.count > 0) {
        NSNumber *refN = refs.firstObject ;
        [self luaUnref:refTable ref:refN.intValue] ;
        holding[refN] = nil ;
    }
}

- (int)luaRef:(int)refTable forNSObject:(id)object {
    if (![self canPushNSObject:object]) return LUA_NOREF ;
    [self pushNSObject:object] ;
    return [self luaRef:refTable] ;
}

#pragma mark - Conversion from NSObjects into Lua objects

- (int)pushNSObject:(id)obj { return [self pushNSObject:obj withOptions:LS_NSNone] ; }

- (int)pushNSObject:(id)obj withOptions:(NSUInteger)options {
    NSMutableDictionary *alreadySeen = [[NSMutableDictionary alloc] init] ;

    int results = [self pushNSObject:obj withOptions:options alreadySeenObjects:alreadySeen];

    for (id entry in alreadySeen) {
        luaL_unref(self.L, LUA_REGISTRYINDEX, [alreadySeen[entry] intValue]) ;
    }
    return results ;
}

- (BOOL)registerPushNSHelper:(pushNSHelperFunction)helperFN forClass:(const char *)cClassName {
    BOOL allGood = NO ;

    NSString *className = nil;
    @try {
        className = @(cClassName);
    } @catch (NSException __unused *exception) {
        className = nil;
    }

    if (className && helperFN) {
        if (self.registeredNSHelperFunctions[className]) {
            [self logAtLevel:LS_LOG_WARN
                 withMessage:[NSString stringWithFormat:@"registerPushNSHelper:forClass:%s already defined at %@",
                                                        cClassName,
                                                        self.registeredNSHelperLocations[className]]] ;
        } else {
            NSString *locationString = getCallerFileName() ;
            if (locationString) {
                self.registeredNSHelperLocations[className] = locationString;
            } else {
                self.registeredNSHelperLocations[className] = @"** unable to determine source file **" ;
            }
            self.registeredNSHelperFunctions[className] = [NSValue valueWithPointer:(void *)helperFN];
            allGood = YES ;
        }
    } else {
        [self logAtLevel:LS_LOG_WARN
             withMessage:@"registerPushNSHelper:forClass: requires both helperFN and className"] ;
    }
    return allGood ;
}

- (int)pushNSRect:(NSRect)theRect {
    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:2 withMessage:"pushNSRect"];

    lua_newtable(self.L) ;
    lua_pushnumber(self.L, theRect.origin.x) ; lua_setfield(self.L, -2, "x") ;
    lua_pushnumber(self.L, theRect.origin.y) ; lua_setfield(self.L, -2, "y") ;
    lua_pushnumber(self.L, theRect.size.width) ; lua_setfield(self.L, -2, "w") ;
    lua_pushnumber(self.L, theRect.size.height) ; lua_setfield(self.L, -2, "h") ;
    lua_pushstring(self.L, "NSRect") ; lua_setfield(self.L, -2, "__luaSkinType") ;
    return 1;
}

- (int)pushNSPoint:(NSPoint)thePoint {
    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:2 withMessage:"pushNSPoint"];

    lua_newtable(self.L) ;
    lua_pushnumber(self.L, thePoint.x) ; lua_setfield(self.L, -2, "x") ;
    lua_pushnumber(self.L, thePoint.y) ; lua_setfield(self.L, -2, "y") ;
    lua_pushstring(self.L, "NSPoint") ; lua_setfield(self.L, -2, "__luaSkinType") ;
    return 1;
}

- (int)pushNSSize:(NSSize)theSize {
    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:2 withMessage:"pushNSSize"];

    lua_newtable(self.L) ;
    lua_pushnumber(self.L, theSize.width) ; lua_setfield(self.L, -2, "w") ;
    lua_pushnumber(self.L, theSize.height) ; lua_setfield(self.L, -2, "h") ;
    lua_pushstring(self.L, "NSSize") ; lua_setfield(self.L, -2, "__luaSkinType") ;
    return 1;
}

- (BOOL)canPushNSObject:(id)obj {
    if (obj) {
        for (id key in self.registeredNSHelperFunctions) {
            if ([obj isKindOfClass: NSClassFromString(key)]) return YES ;
        }
    }
    return NO ;
}

#pragma mark - Conversion from lua objects into NSObjects

- (id)toNSObjectAtIndex:(int)idx { return [self toNSObjectAtIndex:idx withOptions:LS_NSNone] ; }

- (id)toNSObjectAtIndex:(int)idx withOptions:(NSUInteger)options {
    NSMutableDictionary *alreadySeen = [[NSMutableDictionary alloc] init] ;

    // We don't need to deref the already seen objects, like we do for pushNSObject because these are
    // all NSObjectes and not referenced in the LUA_REGISTRY... ARC will take care of this for us.

    return [self toNSObjectAtIndex:idx withOptions:options alreadySeenObjects:alreadySeen] ;
}

- (id)luaObjectAtIndex:(int)idx toClass:(const char *)className {
    NSString *theClass = @(className) ;
    idx = lua_absindex(self.L, idx) ;

    for (id key in self.registeredLuaObjectHelperFunctions) {
        if ([theClass isEqualToString:key]) {
            luaObjectHelperFunction theFunc = (luaObjectHelperFunction)[self.registeredLuaObjectHelperFunctions[key] pointerValue] ;
            return theFunc(self.L, idx) ;
        }
    }
    return nil ;
}

- (BOOL)registerLuaObjectHelper:(luaObjectHelperFunction)helperFN forClass:(const char *)cClassName {
    BOOL allGood = NO ;

    NSString *className = nil;
    @try {
        className = @(cClassName);
    } @catch (NSException __unused *exception) {
        className = nil;
    }

    if (className && helperFN) {
        if (self.registeredLuaObjectHelperFunctions[className]) {
            [self logAtLevel:LS_LOG_WARN
                 withMessage:[NSString stringWithFormat:@"registerLuaObjectHelper:forClass:%s already defined at %@",
                                                        cClassName,
                                                        self.registeredLuaObjectHelperFunctions[className]]] ;
        } else {
            NSString *locationString = getCallerFileName() ;
            if (locationString) {
                self.registeredLuaObjectHelperLocations[className] = locationString;
            } else {
                self.registeredLuaObjectHelperLocations[className] = @"** unable to determine source file **" ;
            }
            self.registeredLuaObjectHelperFunctions[className] = [NSValue valueWithPointer:(void *)helperFN];
            allGood = YES ;
        }
    } else {
        [self logAtLevel:LS_LOG_WARN
             withMessage:@"registerLuaObjectHelper:forClass: requires both helperFN and className"] ;
    }
    return allGood ;
}

- (BOOL)registerLuaObjectHelper:(luaObjectHelperFunction)helperFN forClass:(const char *)className withUserdataMapping:(const char *)cUserdataTag {
    BOOL allGood = [self registerLuaObjectHelper:helperFN forClass:className];
    NSString *userdataTag = @(cUserdataTag);

    if (allGood)
        self.registeredLuaObjectHelperUserdataMappings[userdataTag] = @(className);
    return allGood ;
}

- (BOOL)registerLuaObjectHelper:(luaObjectHelperFunction)helperFN forClass:(const char *)className withUserdataMapping:(const char *)cUserdataTag andTableMapping:(const char *)cTableTag {
    BOOL allGood = [self registerLuaObjectHelper:helperFN forClass:className];
    NSString *userdataTag = @(cUserdataTag);
    NSString *tableTag = @(cTableTag);

    if (allGood) {
        self.registeredLuaObjectHelperUserdataMappings[userdataTag] = @(className);
        self.registeredLuaObjectHelperTableMappings[tableTag] = @(className);
    }
    return allGood ;
}

- (BOOL)registerLuaObjectHelper:(luaObjectHelperFunction)helperFN forClass:(const char *)className withTableMapping:(const char *)cTableTag {
    BOOL allGood = [self registerLuaObjectHelper:helperFN forClass:className];
    NSString *tableTag = @(cTableTag);

    if (allGood)
        self.registeredLuaObjectHelperTableMappings[tableTag] = @(className);
    return allGood ;
}

- (NSRect)tableToRectAtIndex:(int)idx {
    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:4 withMessage:"tableToRectAtIndex"];

    idx = lua_absindex(self.L, idx) ;
    if (lua_type(self.L, idx) == LUA_TTABLE) {
        CGFloat x = (lua_getfield(self.L, idx, "x") == LUA_TNUMBER) ? lua_tonumber(self.L, -1) : 0.0 ;
        CGFloat y = (lua_getfield(self.L, idx, "y") == LUA_TNUMBER) ? lua_tonumber(self.L, -1) : 0.0 ;
        CGFloat w = (lua_getfield(self.L, idx, "w") == LUA_TNUMBER) ? lua_tonumber(self.L, -1) : 0.0 ;
        CGFloat h = (lua_getfield(self.L, idx, "h") == LUA_TNUMBER) ? lua_tonumber(self.L, -1) : 0.0 ;
        lua_pop(self.L, 4);
        return  NSMakeRect(x, y, w, h) ;
    } else {
        [self logAtLevel:LS_LOG_WARN
             withMessage:[NSString stringWithFormat:@"returning NSZeroRect: can't make NSRect from %s.", lua_typename(self.L, lua_type(self.L, idx))]] ;
        return NSZeroRect ;
    }
}

- (NSPoint)tableToPointAtIndex:(int)idx {
    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:2 withMessage:"tableToPointAtIndex"];

    idx = lua_absindex(self.L, idx) ;
    if (lua_type(self.L, idx) == LUA_TTABLE) {
        CGFloat x = (lua_getfield(self.L, idx, "x") == LUA_TNUMBER) ? lua_tonumber(self.L, -1) : 0.0 ;
        CGFloat y = (lua_getfield(self.L, idx, "y") == LUA_TNUMBER) ? lua_tonumber(self.L, -1) : 0.0 ;
        lua_pop(self.L, 2);
        return NSMakePoint(x, y);
    } else {
        [self logAtLevel:LS_LOG_WARN
             withMessage:[NSString stringWithFormat:@"returning NSZeroPoint: can't make NSPoint from %s.", lua_typename(self.L, lua_type(self.L, idx))]] ;
        return NSZeroPoint ;
    }
}

- (NSSize)tableToSizeAtIndex:(int)idx {
    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:2 withMessage:"tableToSizeAtIndex"];

    idx = lua_absindex(self.L, idx) ;
    if (lua_type(self.L, idx) == LUA_TTABLE) {
        CGFloat w = (lua_getfield(self.L, idx, "w") == LUA_TNUMBER) ? lua_tonumber(self.L, -1) : 0.0 ;
        CGFloat h = (lua_getfield(self.L, idx, "h") == LUA_TNUMBER) ? lua_tonumber(self.L, -1) : 0.0 ;
        lua_pop(self.L, 2);
        return NSMakeSize(w, h);
    } else {
        [self logAtLevel:LS_LOG_WARN
             withMessage:[NSString stringWithFormat:@"returning NSZeroSize: can't make NSSize from %s.", lua_typename(self.L, lua_type(self.L, idx))]] ;
        return NSZeroSize ;
    }
}

#pragma mark - Support Functions

// maxn   returns the largest integer key in the table
- (lua_Integer)maxNatIndex:(int)idx {
    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:3 withMessage:"maxNatIndex"];

    idx = lua_absindex(self.L, idx) ;
    lua_Integer max = 0;
    if (lua_type(self.L, idx) == LUA_TTABLE) {
        lua_pushnil(self.L);  /* first key */
        while (lua_next(self.L, idx)) {
            lua_pop(self.L, 1);  /* remove value */
            if (lua_type(self.L, -1) == LUA_TNUMBER && lua_isinteger(self.L, -1)) {
                lua_Integer v = lua_tointeger(self.L, -1);
                if (v > max) max = v;
            }
        }
    } else {
        [self logAtLevel:LS_LOG_ERROR
             withMessage:[NSString stringWithFormat:@"table expected (found %s)", lua_typename(self.L, lua_type(self.L, idx))]] ;
    }
    return max ;
}

// countn returns the number of items of any key type in the table
- (lua_Integer)countNatIndex:(int)idx {
    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:3 withMessage:"countNatIndex"];

    idx = lua_absindex(self.L, idx) ;
    lua_Integer max = 0;
    if (lua_type(self.L, idx) == LUA_TTABLE) {
        lua_pushnil(self.L);  /* first key */
        while (lua_next(self.L, idx)) {
          lua_pop(self.L, 1);  /* remove value */
          max++ ;
        }
    } else {
        [self logAtLevel:LS_LOG_ERROR
             withMessage:[NSString stringWithFormat:@"table expected (found %s)", lua_typename(self.L, lua_type(self.L, idx))]] ;
    }
    return max ;
}

- (BOOL)isValidUTF8AtIndex:(int)idx {
    idx = lua_absindex(self.L, idx) ;
    if (lua_type(self.L, idx) != LUA_TSTRING && lua_type(self.L, idx) != LUA_TNUMBER) return NO ;

    size_t len ;
    unsigned char *str = (unsigned char *)lua_tolstring(self.L, idx, &len) ;

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
    idx = lua_absindex(self.L, idx) ;
    size_t sourceLength ;
    unsigned char *src  = (unsigned char *)luaL_tolstring(self.L, idx, &sourceLength) ;
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
    lua_pop(self.L, 1) ;

    return [[NSString alloc] initWithData:dest encoding:NSUTF8StringEncoding] ;
}

- (BOOL)requireModule:(const char *)moduleName {
    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:2 withMessage:"requireModule"];

    lua_getglobal(self.L, "require"); lua_pushstring(self.L, moduleName) ;
    return [self protectedCallAndTraceback:1 nresults:1] ;
}

- (void)growStack:(int)slots withMessage:(const char *)message {
#if 0
    NSLog(@"growStack: %03d:%s", slots, message);
#endif
    luaL_checkstack(self.L, slots, message);
}

#pragma mark - conversionSupport extensions to LuaSkin class

- (int)pushNSObject:(id)obj withOptions:(NSUInteger)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:2 withMessage:"pushNSObject"];

    if (obj) {
// NOTE: We catch self-referential loops, do we also need a recursive depth?  Will crash at depth of 512...
        if (alreadySeen[obj]) {
            lua_rawgeti(self.L, LUA_REGISTRYINDEX, [alreadySeen[obj] intValue]) ;
            return 1 ;
        }

        // check for registered helpers

        for (id key in self.registeredNSHelperFunctions) {
            if ([obj isKindOfClass: NSClassFromString(key)]) {
                pushNSHelperFunction theFunc = (pushNSHelperFunction)[self.registeredNSHelperFunctions[key] pointerValue] ;
                int resultAnswer = theFunc(self.L, obj) ;
                if (resultAnswer > -1) return resultAnswer ;
            }
        }

        // Check for built-in classes

        if ([obj isKindOfClass:[NSNull class]]) {
            lua_pushnil(self.L) ;
        } else if ([obj isKindOfClass:[NSNumber class]]) {
            [self pushNSNumber:obj withOptions:options] ;
// Note, the NSValue check must come *after* the NSNumber check, as NSNumber is a sub-class of NSValue
        } else if ([obj isKindOfClass:[NSValue class]]) {
            [self pushNSValue:obj withOptions:options] ;
        } else if ([obj isKindOfClass:[NSString class]]) {
                size_t size = [(NSString *)obj lengthOfBytesUsingEncoding:NSUTF8StringEncoding] ;
                lua_pushlstring(self.L, [(NSString *)obj UTF8String], size) ;
        } else if ([obj isKindOfClass:[NSData class]]) {
            lua_pushlstring(self.L, [(NSData *)obj bytes], [(NSData *)obj length]) ;
        } else if ([obj isKindOfClass:[NSDate class]]) {
            lua_pushinteger(self.L, lround([(NSDate *)obj timeIntervalSince1970])) ;
        } else if ([obj isKindOfClass:[NSArray class]]) {
            [self pushNSArray:obj withOptions:options alreadySeenObjects:alreadySeen] ;
        } else if ([obj isKindOfClass:[NSOrderedSet class]]) {
            [self pushNSArray:[obj array] withOptions:options alreadySeenObjects:alreadySeen] ;
        } else if ([obj isKindOfClass:[NSSet class]]) {
            [self pushNSSet:obj withOptions:options alreadySeenObjects:alreadySeen] ;
        } else if ([obj isKindOfClass:[NSDictionary class]]) {
            [self pushNSDictionary:obj withOptions:options alreadySeenObjects:alreadySeen] ;
        } else if ([obj isKindOfClass:[NSURL class]]) {
// normally I'd make a class a helper registered as part of a module; however, NSURL is common enough
// and 99% of the time we just want it stringified... by putting it in here, if someone needs it to do
// more later, they can register a helper to catch the object before it reaches here.
            lua_pushstring(self.L, [[obj absoluteString] UTF8String]) ;
        } else {
            if ((options & LS_NSDescribeUnknownTypes) == LS_NSDescribeUnknownTypes) {
                [self logVerbose:[NSString stringWithFormat:@"unrecognized type %@; converting to '%@'", NSStringFromClass([obj class]), [obj debugDescription]]] ;
                lua_pushstring(self.L, [[NSString stringWithFormat:@"%@", [obj debugDescription]] UTF8String]) ;
            } else if ((options & LS_NSIgnoreUnknownTypes) == LS_NSIgnoreUnknownTypes) {
                [self logVerbose:[NSString stringWithFormat:@"unrecognized type %@; ignoring", NSStringFromClass([obj class])]] ;
                return 0 ;
            } else {
                [self logDebug:[NSString stringWithFormat:@"unrecognized type %@; returning nil", NSStringFromClass([obj class])]] ;
                lua_pushnil(self.L) ;
            }
        }
    } else {
        lua_pushnil(self.L) ;
    }
    return 1 ;
}

- (int)pushNSNumber:(id)obj withOptions:(NSUInteger)options {
    NSNumber    *number = obj ;

    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:2 withMessage:"pushNSNumber"];

    if (number == (id)kCFBooleanTrue)
        lua_pushboolean(self.L, YES);
    else if (number == (id)kCFBooleanFalse)
        lua_pushboolean(self.L, NO);
    else {
        switch([number objCType][0]) {
            case 'c': lua_pushinteger(self.L, [number charValue]) ; break ;
            case 'C': lua_pushinteger(self.L, [number unsignedCharValue]) ; break ;

            case 'i': lua_pushinteger(self.L, [number intValue]) ; break ;
            case 'I': lua_pushinteger(self.L, [number unsignedIntValue]) ; break ;

            case 's': lua_pushinteger(self.L, [number shortValue]) ; break ;
            case 'S': lua_pushinteger(self.L, [number unsignedShortValue]) ; break ;

            case 'l': lua_pushinteger(self.L, [number longValue]) ; break ;
            case 'L': lua_pushinteger(self.L, (long long)[number unsignedLongValue]) ; break ;

            case 'q': lua_pushinteger(self.L, [number longLongValue]) ; break ;

            // Lua only does signed long long, not unsigned, so we have two options
            case 'Q': if ((options & LS_NSUnsignedLongLongPreserveBits) == LS_NSUnsignedLongLongPreserveBits) {
                          lua_pushinteger(self.L, (long long)[number unsignedLongLongValue]) ;
                      } else {
                          if ([number unsignedLongLongValue] < 0x8000000000000000)
                              lua_pushinteger(self.L, (long long)[number unsignedLongLongValue]) ;
                          else
                              lua_pushnumber(self.L, [number unsignedLongLongValue]) ;
                      }
                      break ;

            case 'f': lua_pushnumber(self.L,  (lua_Number)[number floatValue]) ; break ;
            case 'd': lua_pushnumber(self.L,  [number doubleValue]) ; break ;

            default:
                [self logDebug:[NSString stringWithFormat:@"unrecognized numerical type '%s' for '%@'", [number objCType], number]] ;
                lua_pushnumber(self.L, [number doubleValue]) ;
                break ;
        }
    }
    return 1 ;
}

// Note, options is currently unused in this category method, but it's included here in case a
// reason for an NSValue related option comes up
- (int)pushNSValue:(id)obj withOptions:(__unused NSUInteger)options {
    NSValue    *value    = obj;
    const char *objCType = [value objCType];

    // @encode is a compiler directive that can give different results depending upon the
    // architecture, so lets compare apples to apples:
    static dispatch_once_t onceToken;
    static const char *pointEncoding ;
    static const char *sizeEncoding ;
    static const char *rectEncoding ;
    static const char *rangeEncoding ;
    dispatch_once(&onceToken, ^{
        pointEncoding = [[NSValue valueWithPoint:NSZeroPoint] objCType] ;
        sizeEncoding  = [[NSValue valueWithSize:NSZeroSize] objCType] ;
        rectEncoding  = [[NSValue valueWithRect:NSZeroRect] objCType] ;
        rangeEncoding = [[NSValue valueWithRange:NSMakeRange(0,1)] objCType] ;
    });

    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:3 withMessage:"pushNSValue"];

    if (strcmp(objCType, pointEncoding)==0) {
        [self pushNSPoint:[value pointValue]] ;
    } else if (strcmp(objCType, sizeEncoding)==0) {
        [self  pushNSSize:[value sizeValue]] ;
    } else if (strcmp(objCType, rectEncoding)==0) {
        [self  pushNSRect:[value rectValue]] ;
    } else if (strcmp(objCType, rangeEncoding)==0) {
        NSRange holder = [value rangeValue] ;
        lua_newtable(self.L) ;
        lua_pushinteger(self.L, (lua_Integer)holder.location) ; lua_setfield(self.L, -2, "location") ;
        lua_pushinteger(self.L, (lua_Integer)holder.length) ;   lua_setfield(self.L, -2, "length") ;
        lua_pushstring(self.L, "NSRange") ; lua_setfield(self.L, -2, "__luaSkinType") ;
    } else {
        NSUInteger actualSize, alignedSize ;
        NSGetSizeAndAlignment(objCType, &actualSize, &alignedSize) ;

        lua_newtable(self.L) ;
        lua_pushstring(self.L, "NSValue") ; lua_setfield(self.L, -2, "__luaSkinType") ;
        lua_pushstring(self.L, objCType) ;                  lua_setfield(self.L, -2, "objCType") ;
        lua_pushinteger(self.L, (lua_Integer)actualSize) ;  lua_setfield(self.L, -2, "actualSize") ;
        lua_pushinteger(self.L, (lua_Integer)alignedSize) ; lua_setfield(self.L, -2, "alignedSize") ;

        void* ptr = malloc(actualSize) ;
        [value getValue:ptr] ;
        [self pushNSObject:[NSData dataWithBytes:ptr length:actualSize]] ;
        lua_setfield(self.L, -2, "data") ;
        free(ptr) ;
    }
    return 1;
}

- (int)pushNSArray:(id)obj withOptions:(NSUInteger)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
    if ((options & LS_WithObjectWrapper) == LS_WithObjectWrapper) {
        void** valuePtr = lua_newuserdata(self.L, sizeof(NSObject *)) ;
        *valuePtr = (__bridge_retained void *)obj ;
        luaL_getmetatable(self.L, LuaSkin_UD_TAG) ;
        lua_setmetatable(self.L, -2) ;

        lua_newtable(self.L) ;
        lua_pushboolean(self.L, ((options & LS_OW_ReadWrite) == LS_OW_ReadWrite)) ;
        lua_setfield(self.L, -2, "mutable") ;
        lua_pushboolean(self.L, ((options & LS_OW_WithArrayConversion) == LS_OW_WithArrayConversion)) ;
        lua_setfield(self.L, -2, "arrayAutoConversion") ;
        lua_setuservalue(self.L, -2) ;
        lua_pushvalue(self.L, -1) ;
        alreadySeen[obj] = @(luaL_ref(self.L, LUA_REGISTRYINDEX)) ;
    } else {
        NSArray* list = obj;

        // Ensure our Lua stack is large enough for the number of items being pushed
        [self growStack:2 withMessage:"pushNSArray"];

        lua_newtable(self.L);
        alreadySeen[obj] = @(luaL_ref(self.L, LUA_REGISTRYINDEX)) ;
        lua_rawgeti(self.L, LUA_REGISTRYINDEX, [alreadySeen[obj] intValue]) ; // put it back on the stack
        for (id item in list) {
            int results = [self pushNSObject:item withOptions:options alreadySeenObjects:alreadySeen];
    // NOTE: This isn't a true representation of the intent of LS_NSIgnoreUnknownTypes as it will actually put `nil`
    // in the indexed positions... is that a problem?  Keeps the numbering indexing simple, though
            if (results == 0) lua_pushnil(self.L) ;
            lua_rawseti(self.L, -2, luaL_len(self.L, -2) + 1) ;
        }
    }
    return 1 ;
}

- (int)pushNSSet:(id)obj withOptions:(NSUInteger)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
    NSSet* list = obj;

    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:2 withMessage:"pushNSSet"];

    lua_newtable(self.L);
    alreadySeen[obj] = @(luaL_ref(self.L, LUA_REGISTRYINDEX)) ;
    lua_rawgeti(self.L, LUA_REGISTRYINDEX, [alreadySeen[obj] intValue]) ; // put it back on the stack
    for (id item in list) {
        int results = [self pushNSObject:item withOptions:options alreadySeenObjects:alreadySeen];
// NOTE: Since an NSSet is unordered anyways, we're opting for simply disregarding ignored items
        if (results > 0)
            lua_rawseti(self.L, -2, luaL_len(self.L, -2) + 1) ;
    }
    return 1 ;
}

- (int)pushNSDictionary:(id)obj withOptions:(NSUInteger)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
    if ((options & LS_WithObjectWrapper) == LS_WithObjectWrapper) {
        void** valuePtr = lua_newuserdata(self.L, sizeof(NSObject *)) ;
        *valuePtr = (__bridge_retained void *)obj ;
        luaL_getmetatable(self.L, LuaSkin_UD_TAG) ;
        lua_setmetatable(self.L, -2) ;

        lua_newtable(self.L) ;
        lua_pushboolean(self.L, ((options & LS_OW_ReadWrite) == LS_OW_ReadWrite)) ;
        lua_setfield(self.L, -2, "mutable") ;
        lua_pushboolean(self.L, ((options & LS_OW_WithArrayConversion) == LS_OW_WithArrayConversion)) ;
        lua_setfield(self.L, -2, "arrayAutoConversion") ;
        lua_setuservalue(self.L, -2) ;
        lua_pushvalue(self.L, -1) ;
        alreadySeen[obj] = @(luaL_ref(self.L, LUA_REGISTRYINDEX)) ;
    } else {
        NSArray *keys   = [obj allKeys];
        NSArray *values = [obj allValues];

        // Ensure our Lua stack is large enough for the number of items being pushed
        [self growStack:2 withMessage:"pushNSDictionary"];

        lua_newtable(self.L);
        alreadySeen[obj] = @(luaL_ref(self.L, LUA_REGISTRYINDEX)) ;
        lua_rawgeti(self.L, LUA_REGISTRYINDEX, [alreadySeen[obj] intValue]) ; // put it back on the stack
        for (unsigned long i = 0; i < [keys count]; i++) {
            int result = [self pushNSObject:keys[i] withOptions:options alreadySeenObjects:alreadySeen];
            if (result > 0) {
                int result2 = [self pushNSObject:values[i] withOptions:options alreadySeenObjects:alreadySeen];
                if (result2 > 0) {
                    lua_settable(self.L, -3);
                } else {
                    lua_pop(self.L, 1) ; // pop the key since we won't be using it
                }
            } // else nothing was pushed on the stack, so we don't need to pop anything
        }
    }
    return 1 ;
}

- (id)toNSObjectAtIndex:(int)idx withOptions:(NSUInteger)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
    const char *cUserdataTag = nil;
    NSString *userdataTag = nil;

    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:2 withMessage:"toNSObjectAtIndex"];

    idx = lua_absindex(self.L, idx) ;
    NSMutableArray *seenObject = alreadySeen[[NSValue valueWithPointer:lua_topointer(self.L, idx)]] ;
    if (seenObject) {
        if ([[seenObject lastObject] isEqualToNumber:@(NO)] && ((options & LS_NSAllowsSelfReference) != LS_NSAllowsSelfReference)) {
            [self logAtLevel:LS_LOG_WARN
                 withMessage:@"lua table cannot contain self-references"] ;
//             return [NSNull null] ;
            return nil ;
        } else {
            return [seenObject firstObject] ;
        }
    }
    switch (lua_type(self.L, idx)) {
        case LUA_TNUMBER:
            if (lua_isinteger(self.L, idx)) {
                return @(lua_tointeger(self.L, idx)) ;
            } else {
                return @(lua_tonumber(self.L, idx));
            }
        case LUA_TSTRING: {
                LS_NSConversionOptions stringOptions = options & ( LS_NSPreserveLuaStringExactly | LS_NSLuaStringAsDataOnly ) ;
                if (stringOptions == LS_NSLuaStringAsDataOnly) {
                    size_t size ;
                    unsigned char *junk = (unsigned char *)lua_tolstring(self.L, idx, &size) ;
                    return [NSData dataWithBytes:(void *)junk length:size] ;
                } else if (stringOptions == LS_NSPreserveLuaStringExactly) {
                    if ([self isValidUTF8AtIndex:idx]) {
                        size_t size ;
                        unsigned char *string = (unsigned char *)lua_tolstring(self.L, idx, &size) ;
                        return [[NSString alloc] initWithData:[NSData dataWithBytes:(void *)string length:size] encoding: NSUTF8StringEncoding] ;
                    } else {
                        size_t size ;
                        unsigned char *junk = (unsigned char *)lua_tolstring(self.L, idx, &size) ;
                        return [NSData dataWithBytes:(void *)junk length:size] ;
                    }
                } else {
                    if (stringOptions != LS_NSNone) {
                        [self logAtLevel:LS_LOG_DEBUG
                             withMessage:@"only one of LS_NSPreserveLuaStringExactly or LS_NSLuaStringAsDataOnly can be specified: using default behavior"] ;
                    }
                    return [self getValidUTF8AtIndex:idx] ;
                }
            }
        case LUA_TNIL:
            return ([alreadySeen count] > 0) ? [NSNull null] : nil ;
        case LUA_TBOOLEAN:
            return lua_toboolean(self.L, idx) ? (id)kCFBooleanTrue : (id)kCFBooleanFalse;
        case LUA_TTABLE:
            return [self tableAtIndex:idx withOptions:options alreadySeenObjects:alreadySeen] ;
        case LUA_TUSERDATA: // Note: This is specifically last, so it can fall through to the default case, for objects we can't handle automatically
//             //FIXME: This seems very unsafe to happen outside a protected call
//             if (lua_getfield(self.L, idx, "__type") == LUA_TSTRING) {
//                 userdataTag = (char *)lua_tostring(self.L, -1);
//             }
//             lua_pop(self.L, 1);

            if (luaL_testudata(self.L, idx, LuaSkin_UD_TAG)) {
                return (__bridge NSObject *)*((void**)luaL_checkudata(self.L, idx, LuaSkin_UD_TAG)) ;
            }

            lua_pushcfunction(self.L, pushUserdataType) ;
            lua_pushvalue(self.L, idx) ;
            if ((lua_pcall(self.L, 1, 1, 0) == LUA_OK) && (lua_type(self.L, -1) == LUA_TSTRING)) {
               cUserdataTag = lua_tostring(self.L, -1);
            }
            // if the call errors b/c of missing __init in userdata, the error is on the stack, otherwise our result is.
            // In either case clean up after ourself.
            lua_pop(self.L, 1) ;

            userdataTag = @(cUserdataTag);
            if (cUserdataTag) {
                NSString *classMapping = self.registeredLuaObjectHelperUserdataMappings[userdataTag];
                if (classMapping) {
                    return [self luaObjectAtIndex:idx toClass:(const char *)[classMapping UTF8String]];
                } else {
                    [self logBreadcrumb:[NSString stringWithFormat:@"unrecognized userdata type %s", cUserdataTag]] ;
                }
            }
            // we didn't handle the userdata, so fall through
        default:
            if ((options & LS_NSDescribeUnknownTypes) == LS_NSDescribeUnknownTypes) {
                NSString *answer = @(luaL_tolstring(self.L, idx, NULL));
                [self logVerbose:[NSString stringWithFormat:@"unrecognized type %s; converting to '%@'", lua_typename(self.L, lua_type(self.L, idx)), answer]] ;
                lua_pop(self.L, 1) ;
                return answer ;
            } else if ((options & LS_NSIgnoreUnknownTypes) == LS_NSIgnoreUnknownTypes) {
                [self logVerbose:[NSString stringWithFormat:@"unrecognized type %s; ignoring with %s", lua_typename(self.L, lua_type(self.L, idx)), (([alreadySeen count] > 0) ? "placeholder [NSNull null]" : "nil")]] ;
                return ([alreadySeen count] > 0) ? [NSNull null] : nil ;
            } else {
                [self logDebug:[NSString stringWithFormat:@"unrecognized type %s; returning nil", lua_typename(self.L, lua_type(self.L, idx))]] ;
                return nil ;
            }
    }
}

// Note, options is currently unused in this category method, but it's included here in case a
// reason for an NSValue related option comes up
- (id)tableAtIndex:(int)idx withLabel:(const char *)cTableTag withOptions:(__unused NSUInteger)options {
    id result ;
    NSString *tableTag = @(cTableTag);

    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:2 withMessage:"tableAtIndex"];

    idx = lua_absindex(self.L, idx) ;
    NSString *classMapping = self.registeredLuaObjectHelperTableMappings[tableTag];
    if ((classMapping) && self.registeredLuaObjectHelperFunctions[classMapping]) {
        luaObjectHelperFunction theFunc = (luaObjectHelperFunction)[self.registeredLuaObjectHelperFunctions[classMapping] pointerValue] ;
        result = theFunc(self.L, idx) ;
    } else { // check builtins (NSValue)
        if (strcmp(cTableTag, "NSPoint")==0) {
            result = [NSValue valueWithPoint:[self tableToPointAtIndex:idx]] ;
        } else if (strcmp(cTableTag, "NSSize")==0) {
            result = [NSValue valueWithSize:[self tableToSizeAtIndex:idx]] ;
        } else if (strcmp(cTableTag, "NSRect")==0) {
            result = [NSValue valueWithRect:[self tableToRectAtIndex:idx]] ;
        } else if (strcmp(cTableTag, "NSRange")==0) {
            NSRange holder ;
            holder.location = (lua_getfield(self.L, idx, "location") == LUA_TNUMBER) ? (NSUInteger)lua_tointeger(self.L, -1) : 0 ;
            holder.length   = (lua_getfield(self.L, idx, "length")   == LUA_TNUMBER) ? (NSUInteger)lua_tointeger(self.L, -1) : 0 ;
            lua_pop(self.L, 2) ;
            result = [NSValue valueWithRange:holder] ;
        } else if (strcmp(cTableTag, "NSValue")==0) {
            NSData   *rawData ;
            NSString *objCType ;
            if (lua_getfield(self.L, idx, "data") == LUA_TSTRING) {
                rawData = [self toNSObjectAtIndex:-1 withOptions:LS_NSLuaStringAsDataOnly] ;
            }
            if (lua_getfield(self.L, idx, "objCType") == LUA_TSTRING) {
                objCType = [self toNSObjectAtIndex:-1] ;
            }
            if (rawData && objCType) {
                NSUInteger actualSize ;
                const char *asConstChar = [objCType UTF8String] ;
                NSGetSizeAndAlignment(asConstChar, &actualSize, NULL) ;
                if (actualSize == [rawData length]) {
                    result = [NSValue value:[rawData bytes] withObjCType:asConstChar] ;
                } else {
                    [self logError:[NSString stringWithFormat:@"data size of %lu does not match objCType requirements of %lu for %s", [rawData length], actualSize, asConstChar]] ;
                }
            } else {
                [self logError:@"arbitrary NSValue object from table requires data and objCType fields"] ;
            }
            lua_pop(self.L, 2) ;
        }
    }
    return result ;
}

- (id)tableAtIndex:(int)idx withOptions:(NSUInteger)options alreadySeenObjects:(NSMutableDictionary *)alreadySeen {
    id result ;

    // Ensure our Lua stack is large enough for the number of items being pushed
    [self growStack:3 withMessage:"tableAtIndex"];

    idx = lua_absindex(self.L, idx) ;

    if ((lua_getfield(self.L, idx, "__luaSkinType") == LUA_TSTRING) && ((options & LS_NSRawTables) != LS_NSRawTables)) {
        result = [self tableAtIndex:idx withLabel:lua_tostring(self.L, -1) withOptions:options] ;
        if (!result) [self logWarn:[NSString stringWithFormat:@"Unable to create object for __luaSkinType = %s",
                                                              lua_tostring(self.L, -1)]] ;
        lua_pop(self.L, 1) ;
    } else {
        lua_pop(self.L, 1) ;
        if ([self maxNatIndex:idx] == [self countNatIndex:idx]) {
            result = (NSMutableArray *) [[NSMutableArray alloc] init] ;
        } else {
            result = (NSMutableDictionary *) [[NSMutableDictionary alloc] init] ;
        }
        alreadySeen[[NSValue valueWithPointer:lua_topointer(self.L, idx)]] = @[result, @(NO)] ;

        if ([result isKindOfClass: [NSArray class]]) {
            lua_Integer tableLength = [self countNatIndex:idx] ;
            // Ensure our Lua stack is large enough for the number of items being pushed
            [self growStack:(int)tableLength withMessage:"tableAtIndex->NSArray"];
            for (lua_Integer i = 0; i < tableLength ; i++) {
                lua_geti(self.L, idx, i + 1) ;
                id val = [self toNSObjectAtIndex:-1 withOptions:options alreadySeenObjects:alreadySeen] ;
                if (val) {
                    [result addObject:val] ;
                    lua_pop(self.L, 1) ;
                } else {
                    [self logAtLevel:LS_LOG_ERROR
                         withMessage:[NSString stringWithFormat:@"array element (%s) cannot be converted into a proper NSObject",
                                                                 luaL_tolstring(self.L, -1, NULL)]] ;
                    result = nil ;
                    lua_pop(self.L, 2) ; // luaL_tolstring result and lua_geti result
                    return nil ;
                }
            }
        } else {
            lua_pushnil(self.L);
            while (lua_next(self.L, idx) != 0) {
                id key = [self toNSObjectAtIndex:-2             withOptions:options alreadySeenObjects:alreadySeen] ;
                id val = [self toNSObjectAtIndex:lua_gettop(self.L) withOptions:options alreadySeenObjects:alreadySeen] ;
                if (key && val) {
                    [result setValue:val forKey:key];
                    lua_pop(self.L, 1);
                } else {
                    [self logAtLevel:LS_LOG_ERROR
                         withMessage:[NSString stringWithFormat:@"dictionary %@ (%s) cannot be converted into a proper NSObject",
                                                                 (key) ? @"key" : @"value",
                                                                 luaL_tolstring(self.L, (key) ? -2 : lua_gettop(self.L), NULL)]] ;
                    result = nil ;
                    lua_pop(self.L, 3) ; // luaL_tolstring result, lua_next value, and lua_next key
                    return nil ;
                }
            }
        }
    }

    if (result) alreadySeen[[NSValue valueWithPointer:lua_topointer(self.L, idx)]] = @[result, @(YES)] ;
    return result ;
}

#pragma mark - LuaSkin Log Support

- (void) logAtLevel:(int)level withMessage:(NSString *)theMessage {
    // Capture a strong reference to the weak delegate, so it remains reliable during this method
    id theDelegate = self.delegate;

    if (theDelegate &&  [theDelegate respondsToSelector:@selector(logForLuaSkinAtLevel:withMessage:)]) {
        [theDelegate logForLuaSkinAtLevel:level withMessage:theMessage] ;
    } else {
        NSLog(@"(missing delegate):log level %d: %@", level, theMessage) ;
    }
}

// shorthand
- (void)logVerbose:(NSString *)theMessage    { [self logAtLevel:LS_LOG_VERBOSE withMessage:theMessage] ; }
- (void)logDebug:(NSString *)theMessage      { [self logAtLevel:LS_LOG_DEBUG withMessage:theMessage] ; }
- (void)logInfo:(NSString *)theMessage       { [self logAtLevel:LS_LOG_INFO withMessage:theMessage] ; }
- (void)logWarn:(NSString *)theMessage       { [self logAtLevel:LS_LOG_WARN withMessage:theMessage] ; }
- (void)logError:(NSString *)theMessage      { [self logAtLevel:LS_LOG_ERROR withMessage:theMessage] ; }
- (void)logBreadcrumb:(NSString *)theMessage { [self logAtLevel:LS_LOG_BREADCRUMB withMessage:theMessage] ; }

- (void)logKnownBug:(NSString *)message {
    id theDelegate = self.delegate;

    if (theDelegate &&  [theDelegate respondsToSelector:@selector(logKnownBug:)]) {
        [theDelegate logKnownBug:message];
    } else {
        NSLog(@"(missing delegate):known bug: %@", message);
    }

}

+ (void)classLogAtLevel:(int)level withMessage:(NSString *)theMessage {
    if ([NSThread isMainThread]) {
        // the class logging methods *do* use the shared instance, so backup the state/thread in case
        // coroutines involved
        lua_State *backup = _sharedLuaSkin.L ;
        [[[self class] sharedWithState:NULL] logAtLevel:level withMessage:theMessage] ;
        _sharedLuaSkin.L = backup ;
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            // the class logging methods *do* use the shared instance, so backup the state/thread in case
            // coroutines involved
            lua_State *backup = _sharedLuaSkin.L ;
            [[[self class] sharedWithState:NULL] logAtLevel:level
                             withMessage:[@"(secondary thread): " stringByAppendingString:theMessage]] ;
            _sharedLuaSkin.L = backup ;
        }) ;
    }
}

+ (void)logVerbose:(NSString *)theMessage    { [[self class] classLogAtLevel:LS_LOG_VERBOSE withMessage:theMessage]; }
+ (void)logDebug:(NSString *)theMessage      { [[self class] classLogAtLevel:LS_LOG_DEBUG withMessage:theMessage]; }
+ (void)logInfo:(NSString *)theMessage       { [[self class] classLogAtLevel:LS_LOG_INFO withMessage:theMessage]; }
+ (void)logWarn:(NSString *)theMessage       { [[self class] classLogAtLevel:LS_LOG_WARN withMessage:theMessage]; }
+ (void)logError:(NSString *)theMessage      { [[self class] classLogAtLevel:LS_LOG_ERROR withMessage:theMessage]; }
+ (void)logBreadcrumb:(NSString *)theMessage { [[self class] classLogAtLevel:LS_LOG_BREADCRUMB withMessage:theMessage]; }

- (NSString *)tracebackWithTag:(NSString *)theTag fromStackPos:(int)level{
    int topIndex         = lua_gettop(self.L) ;
    int absoluteIndex    = lua_absindex(self.L, topIndex) ;

    luaL_traceback(self.L, self.L, [theTag UTF8String], level) ;
    NSString *result = [NSString stringWithFormat:@"LuaSkin Debug Traceback: top index:%d, absolute:%d\n%s",
                                                  topIndex, absoluteIndex, luaL_tolstring(self.L, -1, NULL)] ;
    lua_pop(self.L, 1) ;
    return result ;
}

@end
