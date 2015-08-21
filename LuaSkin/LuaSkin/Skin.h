//
//  Skin.h
//  LuaSkin
//
//  Created by Chris Jones on 11/06/2015.
//  Copyright (c) 2015 Hammerspoon Project Authors. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "lauxlib.h"
#import "lualib.h"
#import "lua.h"

typedef int (*pushNSHelperFunction) (lua_State *L, id obj);
typedef struct pushNSHelpers {
  const char            *name;
  pushNSHelperFunction  func;
} pushNSHelpers;

@interface LuaSkin : NSObject {
    lua_State *_L;
}

#pragma mark - Skin Properties

@property (atomic, readonly) lua_State *L;

#pragma mark - Class lifecycle

/** Returns the singleton LuaSkin.Skin object
 @return Shared instance of LuaSkin.Skin
 */
+ (id)shared;

/** Initialises a LuaSkin object
 @note Typically you are unlikely to want to use the alloc/init pattern. Instead, see @link shared shared @/link for getting the singleton object. You should only call alloc/init directly if you need to manage multiple Lua environments
 @return An initialised LuaSkin.Skin object
 */
- (id)init;

#pragma mark - lua_State lifecycle

/** Prepares the Lua environment in the LuaSkin object
 @note This method should only ever be called after an explicit call to destroyLuaState. The class initialisation creats a Lua environment.
 */
- (void)createLuaState;

/** Destroys the Lua environment in the LuaSkin object
 */
- (void)destroyLuaState;

/** Recreates the Lua environment in the LuaSkin object, from scratch
 */
- (void)resetLuaState;

#pragma mark - Methods for calling into Lua from C

/** Calls lua_pcall() with debug.traceback() as the message handler
 @code
 // First push a reference to the Lua function you want to call
 lua_rawgeti(L, LUA_REGISTRYINDEX, fnRef);

 // Then push the parameters for that function, in order
 lua_pushnumber(L, 1);

 // Finally, call protectedCallAndTraceback, telling it how
 // many arguments you pushed, and how many results you expect
 BOOL result = [luaSkin protectedCallAndTraceback:1 nresults:0];

 // The boolean return tells you whether the Lua code threw
 // an exception or not
 if (!result) handleSomeError();
 @endcode

 @return NO if the Lua code threw an exception, otherwise YES
 @param nargs An integer specifying how many function arguments you have pushed onto the stack
 @param nresults An integer specifying how many return values the Lua function will push onto the stack
 */
- (BOOL)protectedCallAndTraceback:(int)nargs nresults:(int)nresults;

#pragma mark - Methods for registering libraries with Lua

/** Defines a Lua library and creates a references table for the library
 @code
 static const luaL_Reg myShinyLibrary[] = {
 {"doThing", function_doThing},
 {NULL, NULL} // Library arrays must always end with this
 }
 static const luaL_Reg myShinyMetaLibrary[] = {
 {"__gc", function_doLibraryCleanup},
 {NULL, NULL} // Library arrays must always end with this
 }
 [luaSkin registerLibrary:myShinyLibrary metaFunctions:myShinyMetaLibrary];
 @endcode

 @note Every C function pointer must point to a function of the form: static int someFunction(lua_State *L);

 @param functions - A static array of mappings between Lua function names and C function pointers. This provides the public API of the Lua library
 @param metaFunctions - A static array of mappings between special meta Lua function names (such as "__gc") and C function pointers.
 @return A Lua reference to the table created for this library to store its own references
 */
- (int)registerLibrary:(const luaL_Reg *)functions metaFunctions:(const luaL_Reg *)metaFunctions;

/** Defines a Lua library that creates objects, which have methods
 @code
 char *libraryName = "shinyLibrary";

 static const luaL_Reg myShinyLibrary[] = {
 {"newObject", function_createObject},
 {NULL, NULL} // Library arrays must always end with this
 }
 static const luaL_Reg myShinyMetaLibrary[] = {
 {"__gc", function_doLibraryCleanup},
 {NULL, NULL} // Library arrays must always end with this
 }
 static const luaL_Reg myShinyObjectLibrary[] = {
 {"doThing"}, function_objectDoThing},
 {"__gc"}, function_doObjectCleanup},
 {NULL, NULL} // Library arrays must always end with this
 }
 [luaSkin registerLibraryWithObject:libraryName functions:myShinyLibrary metaFunctions:myShinyMetaLibrary libraryObjectFunctions:myShinyObjectLibrary];
 @endcode

 @note Every C function pointer must point to a function of the form: static int someFunction(lua_State *L);

 @param libraryName - A C string containing the name of this library
 @param functions - A static array of mappings between Lua function names and C function pointers. This provides the public API of the Lua library
 @param metaFunctions - A static array of mappings between special meta Lua function names (such as "__gc") and C function pointers.
 @param objectFunctions - A static array of mappings between Lua object method names and C function pointers. This provides the public API of objects created by this library. Note that this object is also used as the metatable, so special functions (e.g. "__gc") should be included here.
 @return A Lua reference to the table created for this library to store its own references
 */
- (int)registerLibraryWithObject:(char *)libraryName functions:(const luaL_Reg *)functions metaFunctions:(const luaL_Reg *)metaFunctions objectFunctions:(const luaL_Reg *)objectFunctions;

/** Stores a reference to the object at the top of the Lua stack, in the supplied table, and pops the object off the stack

 @note This method is functionally analogous to luaL_ref(), it just takes care of pushing the supplied table ref onto the stack, and removes it afterwards

 @param refTable - An integer reference to a table (e.g. the result of a previous luaRef on a table object)
 @return An integer reference to the object that was at the top of the stack
 */
- (int)luaRef:(int)refTable;

/** Removes a reference from the supplied table

 @note This method is functionally analogous to luaL_unref(), it just takes care of pushing the supplied table ref onto the Lua stack, and removes it afterwards

 @param refTable - An integer reference to a table (e.g the result of a previous luaRef on a table object)
 @param ref - An integer reference for an object that should be removed from the refTable table
 @return An integer, always LUA_NOREF (you are advised to store this value in the variable containing the ref parameter, so it does not become a stale reference)
 */
- (int)luaUnref:(int)refTable ref:(int)ref;

/** Pushes a stored reference onto the Lua stack

 @note This method is functionally analogous to lua_rawgeti(), it just takes care of pushing the supplied table ref onto the Lua stack, and removes it afterwards

 @param refTable - An integer reference to a table (e.h. the result of a previous luaRef on a table object)
 @param ref - An integer reference for an object that should be pushed onto the stack
 @return An integer containing the Lua type of the object pushed onto the stack
 */
- (int)pushLuaRef:(int)refTable ref:(int)ref;

//TODO: Add methods for enforcing Lua function arguments
//TODO: Add methods for converting Lua<->objc types

- (int)pushNSObject:(id)obj ;
- (int)pushNSObject:(id)obj preserveBitsInNSNumber:(BOOL)bitsFlag ;
- (int)pushNSObject:(id)obj withLocalHelpers:(pushNSHelpers *)fnList ;
- (int)pushNSObject:(id)obj withLocalHelpers:(pushNSHelpers *)fnList preserveBitsInNSNumber:(BOOL)bitsFlag ;

- (void)registerPushNSHelper:(pushNSHelperFunction)helperFN forClass:(char *)className ;
- (void)unregisterPushNSHelperForClass:(char *)className ;

// push nil for [NSNull null]
- (int)pushNSNull:(id)obj ;

// push number or integer for [NSNumber ...] depending upon type
// Notes:
//   Attempts to identify type of number and convert with no/minimal loss of precision
//   [NSNumber unsignedLongLongValue] cannot be converted without loss of precision because
//     lua uses signed long long for int.  For values < 0x8000000000000000, lua result is
//     as integer.  Greater values are pushed as lua numbers.
- (int)pushNSNumber:(id)obj ;
- (int)pushNSNumber:(id)obj preserveBits:(BOOL)bitsOverNumber ;

// push string for [NSString ...]
- (int)pushNSString:(id)obj ;

// push string for [NSData ...]
- (int)pushNSData:(id)obj ;

// push integer for [NSDate ...]
// Notes:
//   The integer pushed is the number of seconds since the 1970 epoch and is safe to use
//     with os.date() in lua
- (int)pushNSDate:(id)obj ;

// push table for [NSArray ...]
// Notes:
//   Recursively calls [- pushNSObject:object] for elements in NSArray
//   NSArray indexes start at 0, lua table indexes start at 1.  If index is being used
//     solely to indicate order, this shouldn't matter.  If the index value carries
//     information, make sure to take this shift into account in your lua code.
- (int)pushNSArray:(id)obj ;

// push table for [NSSet ...]
// Notes:
//   Recursively calls [- pushNSObject:object] for elements in NSSet
- (int)pushNSSet:(id)obj ;

// push table for [NSDictionary ...]
// Notes:
//   Recursively calls [- pushNSObject:object] for elements in NSDictionary
- (int)pushNSDictionary:(id)obj ;

// push string representation of an NSObject
// Notes:
//   The string will be in the format "NSObject: %@" where %@ is the object representation
//     returned by descriptionWithLocale: if available, or description otherwise.
- (int)pushNSUnknown:(id)obj ;

@end
