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
#import "lobject.h"
#import "lapi.h"
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
/*! @define LS_TFUNCTION maps to LUA_TFUNCTION */
#define LS_TFUNCTION      1 << 7
/*! @define LS_TUSERDATA maps to LUA_TUSERDATA */
#define LS_TUSERDATA      1 << 8
/*! @define LS_TNONE maps to LUA_TNONE */
#define LS_TNONE          1 << 9
/*! @define LS_TANY indicates that any Lua variable type is accepted */
#define LS_TANY           1 << 10

/*! @/definedblock Bit masks for Lua type checking */

/*!
 @abstract Conversion options for @link pushNSObject:withOptions: @/link and @link toNSObjectAtIndex:withOptions: @/link

   @constant LS_NSNone no options specified, use default beahvior
   @constant LS_NSUnsignedLongLongPreserveBits convert NSNumber that contains an unsigned long long to a lua_Integer (long long) rather than preserve the numerical magnitude with lua_Number (double).  Default is to preserve magnitude when the unsigned long long is greater than 0x7fffffffffffffff.
   @constant LS_NSDescribeUnknownTypes when a date type or sub-type is unrecognized and does not match any defined converter, return a string describing the data (from [NSObject debugDescription] or luaL_tolstring, whichever is appropriate for the initial data type) instead of the default behavior of returing nil for the entire conversion. Not compatible with LS_NSDescribeUnknownTypes.
   @constant LS_NSIgnoreUnknownTypes when a date type or sub-type is unrecognized and does not match any defined converter, return a nil placeholder (from [NSNull null] or lua_pushnil, whichever is appropriate for the initial data type) for the data or sub-component instead of the default behavior of returing nil for the entire conversion. Not compatible with LS_NSDescribeUnknownTypes.
   @constant LS_NSPreserveLuaStringExactly If a Lua string contains character byte sequences which cannot be converted to a proper UTF8 Unicode character, return the string as an NSData object instead of the default lossy behavior of converting invalid sequences into the Unicode Invalid Character code.  You should check your result to see if it is an NSString or an NSData object with the isKindOfClass: message if you select this option. Not compatible with LS_NSLuaStringAsDataOnly.
   @constant LS_NSLuaStringAsDataOnly A lua string is always returned as an NSData object instead of the default lossy behavior of converting invalid sequences into the Unicode Invalid Character code.  Not compatible with LS_NSPreserveLuaStringExactly.
   @constant LS_NSAllowsSelfReference If a lua table contains a self reference (a table value which equals one of tables in which it is nested), allow the same self reference in the NSArray or NSDictionary object being created instead of the defualt behavior of returning nil for the entire conversion.  Note that this option will create an object which likely cannot be fully collected by ARC without additional code due to strong internal references.
 */
typedef enum {
    LS_NSNone                         = 0,

    LS_NSUnsignedLongLongPreserveBits = 1 << 0,
    LS_NSDescribeUnknownTypes         = 1 << 1,
    LS_NSIgnoreUnknownTypes           = 1 << 5,

    LS_NSPreserveLuaStringExactly     = 1 << 2,
    LS_NSLuaStringAsDataOnly          = 1 << 3,
    LS_NSAllowsSelfReference          = 1 << 4
} LS_NSConversionOptions ;

/*!
 @definedblock Log level definitions for logAtLevel:withMessage:
 @hidesingletons
 */
/*! @define LS_LOG_BREADCRUMB for messages that should be considered for recording in crash logs */
#define LS_LOG_BREADCRUMB 6
/*! @define LS_LOG_VERBOSE for messages that contain excessive detail that is usually only of interest during debugging */
#define LS_LOG_VERBOSE  5
/*! @define LS_LOG_DEBUG for messages that are usually only of interest during debugging */
#define LS_LOG_DEBUG    4
/*! @define LS_LOG_INFO for messages that are informative */
#define LS_LOG_INFO     3
/*! @define LS_LOG_WARN for messages that contain warnings */
#define LS_LOG_WARN     2
/*! @define LS_LOG_ERROR for messages that indicate an error has occured */
#define LS_LOG_ERROR    1

/*! @/definedblock Log level definitions */

/*! @abstract a function which provides additional support for LuaSkin to convert an NSObject into a Lua object. Helper functions are registered with @link registerPushNSHelper:forClass: @/link, and are used as needed by @link toNSObjectAtIndex: @/link. */
typedef int (*pushNSHelperFunction)(lua_State *L, id obj);

/*! @abstract a function which provides additional support for LuaSkin to convert a Lua object (usually, but not always, a table or userdata) into an NSObject. Helper functions are registered with @link registerLuaObjectHelper:forClass: @/link, and are used as requested with @link luaObjectAtIndex:toClass: @/link. */
typedef id (*luaObjectHelperFunction)(lua_State *L, int idx);

@class LuaSkin ;

/*!
 @protocol LuaSkinDelegate
 @abstract Delegate method for passing control back to the parent environment for environment specific handling.  Curerntly only offers support for passing log messages back to the parent environment for display or processing.
 */
@protocol LuaSkinDelegate <NSObject>
@optional
/*!
 @abstract Pass log level and message back to parent for handling and/or display
 @discussion If no delegate has been assigned, the message is logged to the system logs via NSLog.
 @param level The message log level as an integer.  Predefined levels are defined and used within LuaSkin itself as (in decreasing level of severity) LS_LOG_ERROR, LS_LOG_WARN, LS_LOG_INFO, LS_LOG_DEBUG, and LS_LOG_VERBOSE.
 @param theMessage The text of the message to be logged.
 */
- (void)logForLuaSkinAtLevel:(int)level withMessage:(NSString *)theMessage ;
@end

/*!
 @class LuaSkin
 @abstract Abstraction layer for common operations on Lua state objects
 @discussion LuaSkin was written for Hammerspoon (although it does not depend on any Hammerspoon functionality) to simplify our use of Lua. It includes a full, unmodified Lua distirbution, and provides an Objective C class that is capable of performing common operations such as creating/destroing a lua_State object, providing shared access to the object, Lua function argument type checking and bi-directional conversion of Lua objects and NSObject objects (with loadable plugins for your own converters)
 */
@interface LuaSkin : NSObject {
    lua_State *_L;
}

#pragma mark - Skin Properties

@property (nonatomic, assign) id  delegate;

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
 @abstract Stores a reference to the object at the specified position of the Lua stack, in the supplied table, without removing the object from the stack

 @param refTable - An integer reference to a table (e.h. the result of a previous luaRef on a table object)
 @param idx - An integer stack position
 @return An integer reference to the object at the specified stack position
 */
- (int)luaRef:(int)refTable atIndex:(int)idx;

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

 @discussion This method takes an NSObject and checks its class against registered classes and then against the built in defaults to determine the best way to represent it in Lua.

 @important This method is equivalent to invoking [LuaSkin pushNSObject:obj withOptions:LS_NSNone].  See @link pushNSObject:withOptions: @/link.
 @important The default classes are (in order): NSNull, NSNumber, NSString, NSData, NSDate, NSArray, NSSet, NSDictionary, NSURL, and NSObject.

 @param obj an NSObject

 @return The number of items pushed onto the lua stack - this will be 1 or 0, if conversion was not possible.
 */
- (int)pushNSObject:(id)obj ;

/*!
 @abstract Pushes an NSObject to the lua stack with the specified options

 @discussion This method takes an NSObject and checks its class against registered classes and then against the built in defaults to determine the best way to represent it in Lua.

 @important The default classes are (in order): NSNull, NSNumber, NSString, NSData, NSDate, NSArray, NSSet, NSDictionary, NSURL, and NSObject.

 @param obj an NSObject
 @param options options for the conversion made by using the bitwise OR operator with members of @link LS_NSConversionOptions @/link.

 @return The number of items pushed onto the lua stack - this will be 1 or 0, if conversion was not possible.
 */
- (int)pushNSObject:(id)obj withOptions:(LS_NSConversionOptions)options ;

/*!
 @abstract Register a helper function for converting an NSObject to its lua equivalent

 @important This method allows registering a new NSObject class for conversion by allowing a module to register a helper function
 @param helperFN a function of the type @link pushNSHelperFunction @/link
 @param className a C string containing the class name of the NSObject type this function can convert
 @returns True if registration was successful, or False if the function was not registered for some reason, most commonly because the class already has a registered conversion function.
 */
- (BOOL)registerPushNSHelper:(pushNSHelperFunction)helperFN forClass:(char *)className ;

/*!
 @abstract Push an NSRect onto the lua stack as a lua geometry object (table with x,y,h, and w keys)

 @important This is included as a separate method because NSRect is a structure, not an NSObject
 @param theRect the rectangle to push onto the lua stack
 @returns The number of items on the lua stack - this is always 1 but is returned to simplify its use in Hammerspoon modules
 */
- (int)pushNSRect:(NSRect)theRect ;

/*!
 @abstract Push an NSPoint onto the lua stack as a lua geometry object (table with x and y keys)

 @important This is included as a separate method because NSPoint is a structure, not an NSObject
 @param thePoint the point to push onto the lua stack
 @returns The number of items on the lua stack - this is always 1 but is returned to simplify its use in Hammerspoon modules
 */
- (int)pushNSPoint:(NSPoint)thePoint ;

/*!
 @abstract Push an NSSize onto the lua stack as a lua geometry object (table with w and h keys)

 @important This is included as a separate method because NSSize is a structure, not an NSObject
 @param theSize the point to push onto the lua stack
 @returns The number of items on the lua stack - this is always 1 but is returned to simplify its use in Hammerspoon modules
 */
- (int)pushNSSize:(NSSize)theSize ;

#pragma mark - Conversion from lua objects into NSObjects

/*! @methodgroup Converting Lua variables into NSObjects */

/*!
 @abstract Return an NSObject containing the best representation of the lua data structure at the specified index

 @discussion This method takes a lua object specified at the provided index and converts it into one of the basic NSObject types.

 @attributelist Basic Lua type to NSObject conversion rules
   nil     - [NSNull null]
   string  - NSString
   number  - NSNumber numberWithInteger: or NSNumber numberWithDouble:
   boolean - NSNumber numberWithBool:
   table   - NSArray if table is non-sparse with only integer keys starting at 1 or NSDictionary otherwise

 @discussion If the type is in the above list, this method returns nil.

 @important This method is equivalent to invoking [LuaSkin toNSObjectAtIndex:idx withOptions:LS_NSNone].  See @link toNSObjectAtIndex:withOptions: @/link.

 @param idx the index on lua stack which contains the data to convert

 @returns An NSObject of the appropriate type or nil if conversion was not possible.
 */
- (id)toNSObjectAtIndex:(int)idx ;

/*!
 @abstract Return an NSObject containing the best representation of the lua data structure at the specified index

 @discussion This method takes a lua object specified at the provided index and converts it into one of the basic NSObject types.

 @attributelist Basic Lua type to NSObject conversion rules
   nil     - [NSNull null]
   string  - NSString or NSData, depending upon options specified
   number  - NSNumber numberWithInteger: or NSNumber numberWithDouble:
   boolean - NSNumber numberWithBool:
   table   - NSArray if table is non-sparse with only integer keys starting at 1 or NSDictionary otherwise

 @discussion If the type is in the above list, this method will return nil for the entire conversion, or [NSNull null] or a description of the unrecognized type  for the data or sub-component depending upon the specified options.

 @param idx the index on lua stack which contains the data to convert
 @param options options for the conversion made by using the bitwise OR operator with members of @link LS_NSConversionOptions @/link.

 @returns An NSObject of the appropriate type or nil if conversion was not possible.
 */
- (id)toNSObjectAtIndex:(int)idx withOptions:(LS_NSConversionOptions)options ;

/*!
 @abstract Return an NSObject containing the best representation of the lua table at the specified index

 @important This method uses registered converter functions provided by the Hammerspoon modules to convert the specified table into a recognizable NSObject.  No converters are included within the LuaSkin.  This method relies upon functions registered with the registerLuaObjectHelper:forClass: method for the conversions
 @param idx the index on lua stack which contains the table to convert
 @param className a C string containing the class name of the NSObject type to return.  If no converter function is currently registered for this type, nil is returned
 @returns An NSObject of the appropriate type depending upon the data on the lua stack and the functions currently registered
 */
- (id)luaObjectAtIndex:(int)idx toClass:(char *)className ;

/*!
 @abstract Register a luaObjectAtIndex:toClass: conversion helper function for the specified class

 @important This method registers a converter function for use with the @link luaObjectAtIndex:toClass: @/link method for converting lua data types into NSObjects
 @param helperFN a function of the type @link luaObjectHelperFunction @/link
 @param className a C string containing the class name of the NSObject type this function can convert
 @returns True if registration was successful, or False if the function was not registered for some reason, most commonly because the class already has a registered conversion function.
 */
- (BOOL)registerLuaObjectHelper:(luaObjectHelperFunction)helperFN forClass:(char *)className ;

/*!
 @abstract Register a luaObjectAtIndex:toClass: conversion helper function for the specified class and record a mapping between a userdata type and the class

 @important This method registers a converter function for use with the @link luaObjectAtIndex:toClass: @/link method for converting lua data types into NSObjects. It builds on @link registerLuaObjectHelper:forClass: @/link by also storing a mapping between the NSObject class and Lua userdata type so userdata objects of this type can be automatically converted with @link toNSObjectAtIndex: @/link and @link toNSObjectAtIndex:withOptions: @/link as well.
 @param helperFN a function of the type @link luaObjectHelperFunction @/link
 @param className a C string containing the class name of the NSObject type this function can convert
 @param userdataTag a C string containing the Lua userdata type that can be converted to an NSObject
 @returns True if registration was successful, or False if the function was not registered for some reason, most commonly because the class already has a registered conversion function.
 */
- (BOOL)registerLuaObjectHelper:(luaObjectHelperFunction)helperFN forClass:(char *)className withUserdataMapping:(char *)userdataTag;

/*!
 @abstract Convert a lua geometry object (table with x,y,h, and w keys) into an NSRect

 @important This is included as a separate method because NSRect is a structure, not an NSObject
 @param idx the index on lua stack which contains the table to convert
 @returns An NSRect created from the specified table
 */
- (NSRect)tableToRectAtIndex:(int)idx ;

/*!
 @abstract Convert a lua geometry object (table with x and y keys) into an NSPoint

 @important This is included as a separate method because NSPoint is a structure, not an NSObject
 @param idx the index on lua stack which contains the table to convert
 @returns An NSPoint created from the specified table
 */
- (NSPoint)tableToPointAtIndex:(int)idx ;

/*!
 @abstract Convert a lua geometry object (table with h and w keys) into an NSSize

 @important This is included as a separate method because NSSize is a structure, not an NSObject
 @param idx the index on lua stack which contains the table to convert
 @returns An NSSize created from the specified table
 */
- (NSSize)tableToSizeAtIndex:(int)idx ;

#pragma mark - Other helpers

/*! @methodgroup Utility methods */

/*!
 @abstract Determines if the string in the lua stack is valid UTF8 or not

 @important This method is used internally to determine if a string should be treated as an NSString or an NSData object.  It is included as a public method because it has uses outside of this as well
 @important This method uses lua_tolstring, which will convert a number on the stack to a string.  As described in the Lua documentation, this will causes problems if you're using lua_next with the same index location
 @param idx the index on lua stack which contains the string to check
 @returns YES if the string can be treated as a valid UTF8 string of characters or NO if it is not a string or if it contains invalid UTF8 byte sequences
 */
- (BOOL)isValidUTF8AtIndex:(int)idx ;

/*!
 @abstract Returns an NSString for the string at the specified index with invalid UTF8 byte sequences converted to the Unicode Invalid Character code.

 @important This method uses luaL_tolstring so __tostring metamethods will be used if the index does not refer to a string or a number.

 @param idx the index on lua stack which contains the lua object

 @returns The "safe" string as an NSString object.
 */
- (NSString *)getValidUTF8AtIndex:(int)idx ;

/*!
 @abstract Returns the largest integer key in the table at the specified index.

 @discussion If this number is equal to the number returned by @link countNatIndex: @/link, then it is safe to infer that the table represents a non-sparse array of elements.

 @param idx the index on lua stack which contains the lua table

 @returns a lua_Integer value containing the largest integer key in the table specified.
 */
- (lua_Integer)maxNatIndex:(int)idx ;

/*!
 @abstract Returns the number of keys in the table at the specified index.

 @discussion This method returns a count of keys of any type in the specified table.  Note that a table which contains an array has implicit integer indexes corresponding to the element's position in the array.  Because of this, you can compare the result of this method to @link maxNatIndex: @/link and if they are equal then it is safe to infer that the table represents a non-sparse array of elements.

 @param idx the index on lua stack which contains the lua table

 @returns a lua_Integer value representing the number of keys in the table specified.
 */
- (lua_Integer)countNatIndex:(int)idx ;

/*!
 @abstract Loads a module and places its return value (usually a table of functions) on the stack

 @important This method performs the equivalent of the lua command `require(...)` and places the return value (usually a table of functions) on the stack, or an error string on the stack if it was unable to load the specified module
 @param moduleName the name of the module to load
 @returns YES if the module loaded successfully or NO if it does not
 */
- (BOOL)requireModule:(char *)moduleName ;

/*!
 @abstract Log the specified message with at the specified level
 @discussion Logs the specified message at the specified level by invoking the delegate method @link logForLuaSkinAtLevel:withMessage: @/link.

 @important If no delegate has been defined, messages are logged to the system console via NSLog.

 @param level The message log level as an integer.  Predefined levels are defined and used within LuaSkin itself as (in decreasing level of severity) @link LS_LOG_ERROR @/link, @link LS_LOG_WARN @/link, @link LS_LOG_INFO @/link, @link LS_LOG_DEBUG @/link, and @link LS_LOG_VERBOSE @/link.
 @param theMessage the message to log
 */
- (void)logAtLevel:(int)level withMessage:(NSString *)theMessage ;

/*!
 @abstract Log the specified message with LS_LOG_VERBOSE level
 @discussion This method is equivalent to invoking @link logAtLevel:withMessage: @/link with level @link LS_LOG_VERBOSE @/link
 @param theMessage the message to log
 */
- (void)logVerbose:(NSString *)theMessage ;
/*!
 @abstract Log the specified message with LS_LOG_DEBUG level
 @discussion This method is equivalent to invoking @link logAtLevel:withMessage: @/link with level @link LS_LOG_DEBUG @/link
 @param theMessage the message to log
 */
- (void)logDebug:(NSString *)theMessage ;
/*!
 @abstract Log the specified message with LS_LOG_INFO level
 @discussion This method is equivalent to invoking @link logAtLevel:withMessage: @/link with level @link LS_LOG_INFO @/link
 @param theMessage the message to log
 */
- (void)logInfo:(NSString *)theMessage ;
/*!
 @abstract Log the specified message with LS_LOG_WARN level
 @discussion This method is equivalent to invoking @link logAtLevel:withMessage: @/link with level @link LS_LOG_WARN @/link
 @param theMessage the message to log
 */
- (void)logWarn:(NSString *)theMessage ;
/*!
 @abstract Log the specified message with LS_LOG_ERROR level
 @discussion This method is equivalent to invoking @link logAtLevel:withMessage: @/link with level @link LS_LOG_ERROR @/link
 @param theMessage the message to log
 */
- (void)logError:(NSString *)theMessage ;
/*!
 @abstract Log the specified message with LS_LOG_BREADCRUMB level
 @discussion This method is equivalent to invoking @link logAtLevel:withMessage: @/link with level @link LS_LOG_BREADCRUMB @/link
 @param theMessage the message to log
 */
- (void)logBreadcrumb:(NSString *)theMessage ;

/*!
 @abstract Returns a string containing the current stack top, the absolute index position of the stack top, and the output from luaL_traceback.

 @important This method is primarily for debugging and may be removed in a future release.

 @param theTag a message to attach to the top of the stack trace
 @param level  - the level at which to start the traceback

 @returns an NSString object containing the output generated.
 */
- (NSString *)tracebackWithTag:(NSString *)theTag fromStackPos:(int)level ;

/*!
 @abstract Log the specified message with at the specified level with the traceback position prepended.

 @discussion Logs the specified message, prepended with the lua chunk name and line number at the specified traceback level, for the specified level.  The log level and combined message is logged with @link logAtLevel:withMessage: @/link.

 @important This method is primarily for testing and may be removed in a future release.

 @param level The message log level as an integer.  Predefined levels are defined and used within LuaSkin itself as (in decreasing level of severity) @link LS_LOG_ERROR @/link, @link LS_LOG_WARN @/link, @link LS_LOG_INFO @/link, @link LS_LOG_DEBUG @/link, and @link LS_LOG_VERBOSE @/link.
 @param theMessage the message to log
 @param pos the lua traceback level to attempt to retrieve the chunk name and line number from
 */
- (void)logAtLevel:(int)level withMessage:(NSString *)theMessage fromStackPos:(int)pos ;


@end

