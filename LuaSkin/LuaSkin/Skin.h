//
//  Skin.h
//  LuaSkin
//
//  Created by Chris Jones on 11/06/2015
//  Copyright (c) 2015 Hammerspoon Project Authors. All rights reserved
//

/*!
     @header Skin.h
     An Objective-C framework that both wraps and abstracts Lua
     @copyright The Hammerspoon Authors
 */


#import <Foundation/Foundation.h>
#import "lauxlib.h"
#import "lualib.h"
#import "lua.h"

// Define some bits for masking operations in the argument checker
/*!
  @definedblock Bit masks for Lua type checking with LuaSkin:checkArgs:
  @hidesingletons
  */

/*! @define LS_TBREAK The final value in all @link //apple_ref/occ/instm/LuaSkin/checkArgs: checkArgs @/link calls, signals the end of the argument list */
#define LS_TBREAK         1 << 0
/*! @define LS_TOPTIONAL Can be OR'd with any argument to indicate that it does not have to be present */
#define LS_TOPTIONAL      1 << 1
/*! @define LS_TNIL maps to LUA_TNIL */
#define LS_TNIL           1 << 2
/*! @define LS_TBOOLEAN maps to LUA_TBOOLEAN */
#define LS_TBOOLEAN       1 << 3
/*! @define LS_TNUMBER maps to LUA_TNUMBER */
#define LS_TNUMBER        1 << 4
/*! @define LS_TSTRING maps to LUA_TSTRING */
#define LS_TSTRING        1 << 5
/*! @define LS_TTABLE maps to LUA_TTABLE */
#define LS_TTABLE         1 << 6
/*! @define LS_TFUNCTION maps to LUA_TTABLE */
#define LS_TFUNCTION      1 << 7
/*! @define LS_TUSERDATA maps to LUA_TUSERDATA */
#define LS_TUSERDATA      1 << 8
/*! @define LS_TNONE maps to LUA_TNONE */
#define LS_TNONE          1 << 9
/*! @define LS_TANY indicates that any Lua variable type is accepted */
#define LS_TANY           1 << 10

/*! @/definedblock Bit masks for Lua type checking */

typedef int (*pushNSHelperFunction) (lua_State *L, id obj);
typedef struct pushNSHelpers {
  const char            *name;
  pushNSHelperFunction  func;
} pushNSHelpers;

typedef id (*luaObjectHelperFunction) (lua_State *L, int idx) ;
typedef struct luaObjectHelpers {
  const char          *name ;
  luaObjectHelperFunction func ;
} luaObjectHelpers ;

/*!
 @class LuaSkin
 @abstract Abstraction layer for common operations on Lua state objects
 @discussion LuaSkin was written for Hammerspoon (although it does not depend on any Hammerspoon functionality) to simplify our use of Lua. It includes a full, unmodified Lua distirbution, and provides an Objective C class that is capable of performing common operations such as creating/destroing a lua_State object, providing shared access to the object, Lua function argument type checking and bi-directional conversion of Lua objects and NSObject objects (with loadable plugins for your own converters)
 */
@interface LuaSkin : NSObject {
    lua_State *_L;
}

#pragma mark - Skin Properties

/*!
 @property L
 @abstract LuaSkin's internal Lua state object
 @discussion Provides access to the raw Lua state object. Care should be taken when using this object, to ensure you are interacting with the Lua stack in a way that makes sense
 */
@property (atomic, readonly) lua_State *L;

#pragma mark - Class lifecycle

/*!
 @abstract Returns the singleton LuaSkin.Skin object
 @return Shared instance of LuaSkin.Skin
 */
+ (id)shared;

/*!
 @abstract Initialises a LuaSkin object
 @discussion Typically you are unlikely to want to use the alloc/init pattern. Instead, see @link shared @/link for getting the singleton object. You should only call alloc/init directly if you need to manage multiple Lua environments
 @return An initialised LuaSkin.Skin object
 */
- (id)init;

#pragma mark - lua_State lifecycle

/*! @methodgroup Lua state lifecycle */

/*!
 @abstract Prepares the Lua environment in the LuaSkin object
 @warning This method should only ever be called after an explicit call to destroyLuaState
 There is no need to call it when initialising a LuaSkin instance
 */
- (void)createLuaState;

/*!
 @abstract Destroys the Lua environment in the LuaSkin object
 */
- (void)destroyLuaState;

/*!
 @abstract Recreates the Lua environment in the LuaSkin object, from scratch
 */
- (void)resetLuaState;

#pragma mark - Methods for calling into Lua from C

/*! @methodgroup Calling Lua functions from Objective C */

/*!
 @abstract Calls lua_pcall() with debug.traceback() as the message handler
 @discussion Here is some sample code:
 <pre>@textblock
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
 @/textblock</pre>

 @return NO if the Lua code threw an exception, otherwise YES
 @param nargs An integer specifying how many function arguments you have pushed onto the stack
 @param nresults An integer specifying how many return values the Lua function will push onto the stack
 */
- (BOOL)protectedCallAndTraceback:(int)nargs nresults:(int)nresults;

#pragma mark - Methods for registering libraries with Lua

/*! @methodgroup Registering module libraries with Lua */

/*!
 @abstract Defines a Lua library and creates a references table for the library
 @discussion Lua libraries defined in C are simple mappings between Lua function names and C function pointers.

 A library consists of a series of Lua functions that are exposed to the user, and (optionally) several special Lua functions that will be used by Lua itself. The most common of these is <tt>__gc</tt> which will be called when Lua is performing garbage collection for the library.
 These "special" functions are stored in the library's metatable. Other common metatable functions include <tt>__tostring</tt> and <tt>__index</tt>.

 The mapping between Lua functions and C functions is done using an array of type <tt>luaL_Reg</tt>

 Every C function pointed to in a <tt>luaL_Reg</tt> array must have the signature: <tt>static int someFunction(lua_State *L);</tt>

 Here is some sample code:
 <pre>@textblock
 static const luaL_Reg myShinyLibrary[] = {
    {"doThing", function_doThing},
    {NULL, NULL} // Library arrays must always end with this
 };

 static const luaL_Reg myShinyMetaLibrary[] = {
    {"__gc", function_doLibraryCleanup},
    {NULL, NULL} // Library arrays must always end with this
 };

 [luaSkin registerLibrary:myShinyLibrary metaFunctions:myShinyMetaLibrary];
 @/textblock</pre>

 @param functions - A static array of mappings between Lua function names and C function pointers. This provides the public API of the Lua library
 @param metaFunctions - A static array of mappings between special meta Lua function names (such as <tt>__gc</tt>) and C function pointers
 @return A Lua reference to the table created for this library to store its own references
 */
- (int)registerLibrary:(const luaL_Reg *)functions metaFunctions:(const luaL_Reg *)metaFunctions;

/*!
 @abstract Defines a Lua library that creates objects, which have methods
 @discussion Here is some sample code:
 <pre>@textblock
 char *libraryName = "shinyLibrary";

 static const luaL_Reg myShinyLibrary[] = {
    {"newObject", function_createObject},
    {NULL, NULL} // Library arrays must always end with this
 };

 static const luaL_Reg myShinyMetaLibrary[] = {
    {"__gc", function_doLibraryCleanup},
    {NULL, NULL} // Library arrays must always end with this
 };

 static const luaL_Reg myShinyObjectLibrary[] = {
    {"doThing", function_objectDoThing},
    {"__gc", function_doObjectCleanup},
    {NULL, NULL} // Library arrays must always end with this
 };

 [luaSkin registerLibraryWithObject:libraryName functions:myShinyLibrary metaFunctions:myShinyMetaLibrary libraryObjectFunctions:myShinyObjectLibrary];
 @/textblock</pre>

 @important Every C function pointer must point to a function of the form: static int someFunction(lua_State *L);

 @param libraryName - A C string containing the name of this library
 @param functions - A static array of mappings between Lua function names and C function pointers. This provides the public API of the Lua library
 @param metaFunctions - A static array of mappings between special meta Lua function names (such as "__gc") and C function pointers
 @param objectFunctions - A static array of mappings between Lua object method names and C function pointers. This provides the public API of objects created by this library. Note that this object is also used as the metatable, so special functions (e.g. "__gc") should be included here
 @return A Lua reference to the table created for this library to store its own references
 */
- (int)registerLibraryWithObject:(char *)libraryName functions:(const luaL_Reg *)functions metaFunctions:(const luaL_Reg *)metaFunctions objectFunctions:(const luaL_Reg *)objectFunctions;

/*!
 @abstract Defines a Lua object with methods
 @discussion Here is some sample code:
 <pre>@textblock
 char *objectName = "shinyObject";

 static const luaL_Reg myShinyObject[] = {
    {"doThing", function_objectDoThing},
    {"__gc", function_objectCleanup},
    {NULL, NULL} // Function arrays must always end with this
 };

 [luaSkin registerObject:objectName objectFunctions:myShinyObject];
 @/textblock</pre>

 @important Every C function pointer must point to a function of the form: static int someFunction(lua_State *L);

 @param objectName - A C string containing the name of this object
 @param objectFunctions - A static array of mappings between Lua object method names and C function pointers. This provides the public API of the objects. Note that this array is also used as the metatable, so special functions (e.g. "__gc") should be included here
 */
- (void)registerObject:(char *)objectName objectFunctions:(const luaL_Reg *)objectFunctions;

/*! @methodgroup Referencing Lua objects in Objective C */

/*!
 @abstract Stores a reference to the object at the top of the Lua stack, in the supplied table, and pops the object off the stack
 @important This method is functionally analogous to luaL_ref(), it just takes care of pushing the supplied table ref onto the stack, and removes it afterwards

 @param refTable - An integer reference to a table (e.g. the result of a previous luaRef on a table object)
 @return An integer reference to the object that was at the top of the stack
 */
- (int)luaRef:(int)refTable;

/*!
 @abstract Removes a reference from the supplied table

 @important This method is functionally analogous to luaL_unref(), it just takes care of pushing the supplied table ref onto the Lua stack, and removes it afterwards

 @param refTable - An integer reference to a table (e.g the result of a previous luaRef on a table object)
 @param ref - An integer reference for an object that should be removed from the refTable table
 @return An integer, always LUA_NOREF (you are advised to store this value in the variable containing the ref parameter, so it does not become a stale reference)
 */
- (int)luaUnref:(int)refTable ref:(int)ref;

/*!
 @abstract Pushes a stored reference onto the Lua stack

 @important This method is functionally analogous to lua_rawgeti(), it just takes care of pushing the supplied table ref onto the Lua stack, and removes it afterwards

 @param refTable - An integer reference to a table (e.h. the result of a previous luaRef on a table object)
 @param ref - An integer reference for an object that should be pushed onto the stack
 @return An integer containing the Lua type of the object pushed onto the stack
 */
- (int)pushLuaRef:(int)refTable ref:(int)ref;

/*! @methodgroup Checking Lua arguments in Objective C functions */

/*!
 @abstract Ensures a Lua->C call has the right arguments
 @important If the arguments are incorrect, this call will never return and the user will get a nice Lua traceback instead
 @important Each argument can use boolean OR's to allow multiple types to be accepted (e.g. LS_TNIL | LS_TBOOLEAN)
 @important Each argument can be OR'd with LS_TOPTIONAL to indicate that the argument is optional
 @important LS_TUSERDATA arguments should be followed by a string containing the metatable tag name (e.g. "hs.screen" for objects from hs.screen)
 @important The final argument MUST be LS_TBREAK, to signal the end of the list

 @param firstArg - An integer that defines the first acceptable Lua argument type. Possible values are LS_TNIL, LS_TBOOLEAN, LS_TNUMBER, LS_TSTRING, LS_TTABLE, LS_TFUNCTION, LS_TUSERDATA, LS_TBREAK. Followed by zero or more integers of the same possible values. The final value MUST be LS_TBREAK
 */
- (void)checkArgs:(int)firstArg, ...;

#pragma mark - Conversion from NSObjects into Lua objects

/*! @methodgroup Converting NSObject objects into Lua variables */

/*!
 @abstract Pushes an NSObject to the lua stack
 @important This method takes an NSObject and checks its class against registered classes and then against the built in defaults
     to determine the best way to represent it in Lua.  This variant attempts to preserver the numerical value of NSNumber
     when it encapsulates an unsigned long long by converting it to a lua number (real)
 @important The default classes are (in order): NSNull, NSNumber, NSString, NSData, NSDate, NSArray, NSSet, NSDictionary, and NSObject.  This last is a catch all and will return a string of the NSObjects description method
 @param obj - an NSObject
 @return The number of items on the lua stack - this is always 1 but is returned to simplify its use in Hammerspoon modules
 */
- (int)pushNSObject:(id)obj ;

/*!
 @abstract Pushes an NSObject to the lua stack and optionally preserves the bits rather then the numerical value of unsigned long long NSNumbers

 @important This method takes an NSObject and checks its class against registered classes and then against the built in defaults
     to determine the best way to represent it in Lua.  This variant can optionally preserve the bit pattern of unsigned
     long long NSNumbers rather than the numerical value
 @important The default classes are (in order): NSNull, NSNumber, NSString, NSData, NSDate, NSArray, NSSet, NSDictionary, and NSObject.  This last is a catch all and will return a string of the NSObjects description method
 @param obj - an NSObject
 @param bitsFlag - YES if bits are to be preserved at all costs, NO if an unsigned long long > 0x7fffffff should be treated as a number
 @return The number of items on the lua stack - this is always 1 but is returned to simplify its use in Hammerspoon modules
 */
- (int)pushNSObject:(id)obj preserveBitsInNSNumber:(BOOL)bitsFlag ;

/*!
 @abstract Register a helper function for converting an NSObject to its lua equivalant

 @important This method allows registering a new NSObject class for conversion by allowing a module to register a helper function
 @param helperFN - a function of the type 'int (*pushNSHelperFunction) (lua_State *L, id obj)'
 @param className - a string containing the class name of the NSObject type this function can convert
 */
- (void)registerPushNSHelper:(pushNSHelperFunction)helperFN forClass:(char *)className ;

/*!
 @abstract Push an NSRect onto the lua stack as a lua geometry object (table with x,y,h, and w keys)

 @important This is included as a separate method because NSRect is a structure, not an NSObject
 @param theRect - the rectangle to push onto the lua stack
 @returns The number of items on the lua stack - this is always 1 but is returned to simplify its use in Hammerspoon modules
 */
- (int)pushNSRect:(NSRect)theRect ;

/*!
 @abstract Push an NSPoint onto the lua stack as a lua geometry object (table with x and y keys)

 @important This is included as a separate method because NSPoint is a structure, not an NSObject
 @param thePoint - the point to push onto the lua stack
 @returns The number of items on the lua stack - this is always 1 but is returned to simplify its use in Hammerspoon modules
 */
- (int)pushNSPoint:(NSPoint)thePoint ;

/*!
 @abstract Push an NSSize onto the lua stack as a lua geometry object (table with w and h keys)

 @important This is included as a separate method because NSSize is a structure, not an NSObject
 @param theSize - the point to push onto the lua stack
 @returns The number of items on the lua stack - this is always 1 but is returned to simplify its use in Hammerspoon modules
 */
- (int)pushNSSize:(NSSize)theSize ;

#pragma mark - Conversion from lua objects into NSObjects

/*! @methodgroup Converting Lua variables into NSObjects */

/*!
 @abstract Return an NSObject containing the best representation of the lua data structure at the specified index

 @important In general, it is probably best to use the lua C-API for getting the specific data you require - this method is provided for cases where acceptable data types are more easily vetted by the receiver than in a modules code.  Examples include hs.settings and hs.json
 @important This variant does not support self-referential tables (i.e. tables which contain themselves as a reference)
 @important If a table contians only consecutive numerical indexes which start at 1, the table is converted to an NSArray; otherwise it is converted into an NSDictionary
 @important If a string contains only bytes representing valid UTF8 characters, it is converted to an NSString; otherwise it is converted into an NSData
 @param idx - the index on lua stack which contains the data to convert
 @returns An NSObject of the appropriate type depending upon the data on the lua stack
 */
- (id)toNSObjectAtIndex:(int)idx ;

/*!
 @abstract Return an NSObject containing the best representation of the lua data structure at the specified index

 @important In general, it is probably best to use the lua C-API for getting the specific data you require - this method is provided for cases where acceptable data types are more easily vetted by the receiver than in a modules code.  Examples include hs.settings and hs.json
 @important This variant does not support self-referential tables (i.e. tables which contain themselves as a reference)
 @important If a table contians only consecutive numerical indexes which start at 1, the table is converted to an NSArray; otherwise it is converted into an NSDictionary
 @important If a string contains only bytes representing valid UTF8 characters, it is converted to an NSString; otherwise it is converted into an NSData
 @param idx - the index on lua stack which contains the data to convert
 @param allow - YES indicates that self-referential tables (i.e. tables which contain themselves as a reference) are allowed; NO if they are not
 @returns An NSObject of the appropriate type depending upon the data on the lua stack
 */
- (id)toNSObjectAtIndex:(int)idx allowSelfReference:(BOOL)allow ;


/*!
 @abstract Return an NSObject containing the best representation of the lua table at the specified index

 @important This method uses registered converter functions provided by the Hammerspoon modules to convert the specified table into a recognizable NSObject.  No converters are included within the LuaSkin.  This method relies upon functions registered with the registerLuaObjectHelper:forClass: method for the conversions
 @param idx - the index on lua stack which contains the table to convert
 @param className - a string containing the class name of the NSObject type to return.  If no converter function is currently registered for this type, nil is returned
 @returns An NSObject of the appropriate type depending upon the data on the lua stack and the functions currently registered
 */
- (id)luaObjectAtIndex:(int)idx toClass:(char *)className ;

/*!
 @abstract Register a luaObjectAtIndex:toClass: conversion helper function for the specified class

 @important This method registers a converter functions for use with the luaObjectAtIndex:toClass: method for converting lua tables into NSObjects
 @param helperFN - a function of the type 'id (*luaObjectHelperFunction) (lua_State *L, int idx)'
 @param className - a string containing the class name of the NSObject type this function can convert
 */
- (void)registerLuaObjectHelper:(luaObjectHelperFunction)helperFN forClass:(char *)className ;

/*!
 @abstract Convert a lua geometry object (table with x,y,h, and w keys) into an NSRect

 @important This is included as a separate method because NSRect is a structure, not an NSObject
 @param idx - the index on lua stack which contains the table to convert
 @returns An NSRect created from the specified table
 */
- (NSRect)tableToRectAtIndex:(int)idx ;

/*!
 @abstract Convert a lua geometry object (table with x and y keys) into an NSPoint

 @important This is included as a separate method because NSPoint is a structure, not an NSObject
 @param idx - the index on lua stack which contains the table to convert
 @returns An NSPoint created from the specified table
 */
- (NSPoint)tableToPointAtIndex:(int)idx ;

/*!
 @abstract Convert a lua geometry object (table with h and w keys) into an NSSize

 @important This is included as a separate method because NSSize is a structure, not an NSObject
 @param idx - the index on lua stack which contains the table to convert
 @returns An NSSize created from the specified table
 */
- (NSSize)tableToSizeAtIndex:(int)idx ;

#pragma mark - Other helpers

/*! @methodgroup Utility methods */
/*!
 @abstract Determines if the string in the lua stack is valid UTF8 or not

 @important This method is used internally to determine if a string should be treated as an NSString or an NSData object.  It is included as a public method because it has uses outside of this as well
 @important This method uses lua_tolstring, which will convert a number on the stack to a string.  As described in the Lua documentation, this will causes problems if you're using lua_next with the same index location
 @param idx - the index on lua stack which contains the string to check
 @returns YES if the string can be treated as a valid UTF8 string of characters or NO if it is not a string or if it contains invalid UTF8 byte sequences
 */
- (BOOL)isValidUTF8AtIndex:(int)idx ;

/*!
 @abstract Loads a module and places its return value (usually a table of functions) on the stack

 @important This method performs the equivalent of the lua command `require(...)` and places the return value (usually a table of functions) on the stack, or an error string on the stack if it was unable to load the specified module
 @param moduleName - the name of the module to load
 @returns YES if the module loaded successfully or NO if it does not
 */
- (BOOL)requireModule:(char *)moduleName ;

@end

