#include "lua.h"
#include "lobjectivec_exceptions.h"

#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>

// Note: The __cplusplus stuff will only work on 'modern' Obj-C runtimes that unify Obj-C/C++ exceptions.
// And this file must be compiled as Obj-C++ (.mm) for the C++ condiditionals to take effect.
// C++ is optional and only if you want more specific information returned to the pcall for std::exception.
#if defined(__cplusplus)
	#include <exception>
#endif

#if __has_feature(objc_arc)
//	#warning "Be aware that ARC likes to leak memory with exception handling by default. Please the llvm docs about ARC and Exceptions and the -fobjc-arc-exceptions switch."
#endif

/*	Optimization Notes:
	After doing some benchmarks, I discovered my original implementation was slower than the original _setjmp/_longjmp implementation.
	I had an @autoreleasepool wrapping the @try/@catch block at the top of luai_objcttry. 
	After doing benchmarks and profiling with Instruments, I discovered that the overhead of NSAutoreleasePool
	was causing the performance to be twice as slow as the original _setjmp/_longjmp implementation, even with 64-bit Zero Cost Exceptions.
	It also seems that _setjmp/_longjmp are pretty optimized already compared to their setjmp/longjmp counterparts.

	In a loop of 100,000,000 lua_*call's on an iMac i3 64-bit (non-exceptional case), 
	lua_call was about 12 seconds
	lua_pcall with _setjmp/_longjmp was about 14 seconds
	lua_pcall with @autoreleasepool/@try/@catch was about 24 seconds
	lua_pcall with setjmp/longjmp was about 59 seconds
 
	Once I removed the @autoreleasepool, the exception performance matched the _setjmp/_longjmp performance at about 14 seconds.

	But to remove the @autoreleasepool, I needed to do some tricky things and make certain assuptions.
	I originally tried to avoid wrapping @try in an @autoreleasepool and put @autoreleasepool inside the @catches and @throw. But that still leaked, particularly on the @throw.
	So the lesson learned is that the @throw in luai_objcthrow can't use autorelease (directly or indirectly) if I'm going to remove @autoreleasepool.

	Trick 1: Instead of creating a new instance in luai_objcthrow of NSException (which may use autorelease under the hood), make my own trivial static NSString which avoids any use of alloc and autorelease. Fortunately, we don't really need any information passed along so the object is trivial. 
 
	Trick 2: In the @catch blocks, look for an NSString that represents the normal Lua error. I am interested more in the unique pointer identifier than the string contents so a simple pointer compare is sufficient. 
 
	Trick 3: Using static memory allows me to make this implementation ARC compilable. Otherwise it would try to autorelease my exception objects in luai_objcthrow and cause leaks. 
 
	Trick 4: All other NSExceptions and NSObjects assume an NSAutoreleasePool was created elsewhere. The assumption is that if something had the ability to create those other objects, we are already surrounded by an NSAutoreleasePool from somewhere else. So this means all those other cases should continue to work correctly and not leak.
 
	Trick 5: The use of static memory is also Obj-C Garbage Collection compatible.

 
	Other ARC Notes: 
	ARC is not exception safe by default and may leak.
	http://clang.llvm.org/docs/AutomaticReferenceCounting.html
	The assumption is that exceptions in Objective-C are programmer errors and the application should immediately quit right after. But lua_pcall was designed to trap errors and explictly avoid bringing down your program on an error and was intended to allow you to decide to keep running. In order to allow Lua to not get borked when an Obj-C exception is triggered (perhaps due to something a scripter did to making a native Cocoa call), the two must necessarily be unified. But a frequent assumption in Lua is that a bad script should not necessarily bring down the entire program. There are other uses of pcall, such as testing user input (perhaps the user types Lua commands directly into the program), or testing for the existence of a module (dkjson looks for LPeg and if it fails, falls back to a slower path).

	Using the flag -fobjc-arc-exceptions supposedly corrects some of these issues, presumably with trade-offs. For purposes of this file's implementation, there is no Objective-C dynamic memory allocation so there should be no leaks within this implementation.
 
*/
 

// I want something I can easily identify in a @catch block (some NSObject), but I also want to use static memory to avoid problems with ARC/GC.
// A string constant seems to solve this problem nicely at the cost of needing a persistent string.
static NSString* const kLuai_TraditionalLuaRuntimeErrorIdentifier = @"kLuai_TraditionalLuaRuntimeErrorIdentifier";

/* 
Previously in my 5.1 patch, I introduced 
#define LUA_ERR_EXCEPTION_OBJC 6
#define LUA_ERR_EXCEPTION_CPP 7
#define LUA_ERR_EXCEPTION_OTHER 8
But re-considering and re-reading Programming in Lua 25.2 (1st ed), 
"For normal errors, lua_pcall returns the error code LUA_ERRRUN."
I'm changing these to all be LUA_ERRRUN.
I'm leaving the names here in case you want to change them back easily.
*/

#define LUA_ERR_EXCEPTION_OBJC LUA_ERRRUN
#define LUA_ERR_EXCEPTION_CPP LUA_ERRRUN
#define LUA_ERR_EXCEPTION_OTHER LUA_ERRRUN


void luai_objcttry(lua_State* L, struct lua_longjmp* c_lua_longjmp, Pfunc a_func, void* userdata)
{
	@try
	{
		(*a_func)(L, userdata);
	}
	// We make normal Lua errors throw a static NSString so we can easily identify it. Look for Lua errors first.
	@catch(NSString* exception)
	{
		// Check for our special Lua error type
		// I don't really care about the string contents. I really want the unique pointer address as the identifer.
		// If somebody else happened to pick the exact same string, I don't know if I really want to treat it as the same thing.
		// So instead of using isEqualToString, I am going to do raw pointer equality.
		if(kLuai_TraditionalLuaRuntimeErrorIdentifier == exception)
		{
			// Just in case it isn't set
			if(c_lua_longjmp->status == 0)
			{
				c_lua_longjmp->status = -1;
			}
		}
		else
		{
			lua_pushlstring(L, [exception UTF8String], [exception length]);
			if(c_lua_longjmp->status == 0)
			{
				c_lua_longjmp->status = LUA_ERR_EXCEPTION_OBJC;
			}
		}
	}
	// Expecting an NSException, but Apple's docs warn that it is possible to get something else.
	@catch(NSException* exception)
	{
		lua_pushfstring(L, "%s: %s\n%s", [[exception name] UTF8String], [[exception reason] UTF8String], [[[exception callStackSymbols] description] UTF8String]);
		if(c_lua_longjmp->status == 0)
		{
			c_lua_longjmp->status = LUA_ERR_EXCEPTION_OBJC;
		}
	}
	@catch(NSObject* exception)
	{
		// This is not a NSException, but we can at least print the object.
		lua_pushfstring(L, "Unknown Objective-C exception: %s", [[exception description] UTF8String]);
		if(c_lua_longjmp->status == 0)
		{
			c_lua_longjmp->status = LUA_ERR_EXCEPTION_OBJC;
		}
	}
	@catch(__unused id exception)
	{
		// Not sure what this object is. I don't know what methods it actually implements so I can't easily/safely extract any info.
		lua_pushliteral(L, "Unknown Objective-C exception");
		if(c_lua_longjmp->status == 0)
		{
			c_lua_longjmp->status = LUA_ERR_EXCEPTION_OBJC;
		}
	}
	// Catch anything else, including C++ exceptions when using the modern Obj-C runtime.
	@catch(...)
	{
#if defined(__cplusplus)
		// Non-ObjC exception. Decode it by rethrowing it inside a C++ try/catch.
		try
		{
			@throw;
		}
		catch(std::exception& exception)
		{
			lua_pushstring(L, exception.what());
			if(c_lua_longjmp->status == 0)
			{
				c_lua_longjmp->status = LUA_ERR_EXCEPTION_CPP;
			}
		}
		catch(...)
		{
			// Other C++ exception
			// or non-ObjC non-C++ foreign exception
			// The official Lua code sets the error to -1 for C++ exception handling.
			if(c_lua_longjmp->status == 0)
			{
				lua_pushliteral(L, "Unknown exception");
				c_lua_longjmp->status = LUA_ERR_EXCEPTION_OTHER;
			}
		}
#endif		
		// The official Lua code sets the error to -1 for C++ exception handling.
		if(c_lua_longjmp->status == 0)
		{
			lua_pushliteral(L, "Unknown exception");
			c_lua_longjmp->status = LUA_ERR_EXCEPTION_OTHER;
		}
	}
}

void luai_objcthrow(__unused struct lua_longjmp* errorJmp)
{
	// This must not be autoreleased because Lua doesn't have its own autorelease pool. (See Optimization Notes at the top).
	// To be nice to ARC, I moved to a static NSString away from a custom NSObject that I made sure never got autoreleased.
	// This required a release in the @catch block which didn't work with ARC.
	// The static string makes this go away at the cost of a persistent string.
	@throw(kLuai_TraditionalLuaRuntimeErrorIdentifier);
}

