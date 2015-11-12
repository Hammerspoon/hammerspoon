#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

#define USERDATA_TAG "hs.task"

typedef struct _task_userdata_t {
    void *nsTask;
    int luaCallback;
    void *launchPath;
    void *arguments;
} task_userdata_t;

int refTable;
NSMutableArray *tasks;

NSPointerArray *pointerArrayFromNSTask(NSTask *task) {
    NSPointerArray *result = nil;

    for (NSPointerArray *pointerArray in tasks) {
        if ((__bridge NSTask *)[pointerArray pointerAtIndex:0] == task) {
            result = pointerArray;
            break;
        }
    }

    return result;
}

task_userdata_t *userDataFromNSTask(NSTask *task) {
    task_userdata_t *result = NULL;
    NSPointerArray *pointerArray = pointerArrayFromNSTask(task);

    if (pointerArray) {
        result = [pointerArray pointerAtIndex:1];
    }

    return result;
}

void create_task(task_userdata_t *userData) {
    NSTask *task = [[NSTask alloc] init];
    NSPipe *stdOut = [NSPipe pipe];
    NSPipe *stdErr = [NSPipe pipe];

    userData->nsTask = (__bridge_retained void*)task;
    task.standardOutput = stdOut;
    task.standardError = stdErr;

    task.launchPath = (__bridge NSString *)userData->launchPath;
    task.arguments = (__bridge NSArray *)userData->arguments;
    task.terminationHandler = ^(NSTask *task){
        // Ensure this callback happens on the main thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            task_userdata_t *userData = NULL;
            LuaSkin *skin = [LuaSkin shared];

            NSString *stdOut = [[NSString alloc] initWithData:[[task.standardOutput fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
            NSString *stdErr = [[NSString alloc] initWithData:[[task.standardError fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];

            userData = userDataFromNSTask(task);

            if (!userData) {
                NSLog(@"NSTask terminationHandler called on a task we don't recognise. This was likely a stuck process, or one that didn't respond to SIGTERM, and we have already GC'd its objects. Ignoring");
                return;
            }

            if (userData->luaCallback != LUA_NOREF && userData->luaCallback != LUA_REFNIL) {
                [skin pushLuaRef:refTable ref:userData->luaCallback];
                lua_pushinteger(skin.L, task.terminationStatus);
                [skin pushNSObject:stdOut];
                [skin pushNSObject:stdErr];

                [skin protectedCallAndTraceback:3 nresults:0];
            }
        });
    };

    return;
}

/// hs.task.new(launchPath, callbackFn[, arguments]) -> hs.task object
/// Function
/// Creates a new hs.task object
///
/// Parameters:
///  * launchPath - A string containing the path to an executable file
///  * callbackFn - A callback function to be called when the task terminates, or nil if no callback should be called. The function should accept three arguments:
///   * exitCode - An integer containing the exit code of the process
///   * stdOut - A string containing the standard output of the process
///   * stdErr - A string containing the standard error output of the process
///  * arguments - An optional table containing command line arguments for the executable
///
/// Returns:
///  * An `hs.task` object
static int task_new(lua_State *L) {
    // Check our arguments
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TFUNCTION|LS_TNIL, LS_TTABLE|LS_TOPTIONAL, LS_TBREAK];

    // Create our Lua userdata object
    task_userdata_t *userData = lua_newuserdata(L, sizeof(task_userdata_t));
    memset(userData, 0, sizeof(task_userdata_t));
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    // Capture data in the Lua userdata object
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        userData->luaCallback = [skin luaRef:refTable];
    } else {
        userData->luaCallback = LUA_REFNIL;
    }

    userData->launchPath = (__bridge_retained void *)[skin toNSObjectAtIndex:1];
    if (lua_type(L, 3) == LUA_TTABLE) {
        userData->arguments = (__bridge_retained void *)[skin toNSObjectAtIndex:3];
    } else {
        userData->arguments = (__bridge_retained void *)[[NSArray alloc] init];
    }

    // Create and populate the NSTask object
    create_task(userData);

    // Keep a mapping between the NSTask object and its Lua wrapper
    NSPointerArray *pointers = [[NSPointerArray alloc] initWithOptions:NSPointerFunctionsOpaqueMemory|NSPointerFunctionsOpaquePersonality];
    [pointers addPointer:userData->nsTask];
    [pointers addPointer:(void *)userData];
    [tasks addObject:pointers];

    return 1;
}

/// hs.task:pid() -> integer
/// Method
/// Gets the PID of a running/finished task
///
/// Parameters:
///  * None
///
/// Returns:
///  * An integer containing the PID of the task
///
/// Notes:
///  * The PID will still be returned if the task has already completed and the process terminated
static int task_getPID(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);

    lua_pushinteger(L, [(__bridge NSTask *)userData->nsTask processIdentifier]);
    return 1;
}

/// hs.task:start() -> boolean
/// Method
/// Starts the task
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if the task was launched successfully, otherwise false
///
/// Notes:
///  * If the task was not started successfully, an informative error message will be printed to the Hammerspoon Console
static int task_launch(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);
    BOOL result = false;

    @try {
        [(__bridge NSTask *)userData->nsTask launch];
        result = true;
    }
    @catch (NSException *exception) {
        printToConsole(skin.L, "ERROR: Unable to launch hs.task process:");
        printToConsole(skin.L, (char *)[exception.reason UTF8String]);
    }

    lua_pushboolean(L, result);
    return 1;
}

/// hs.task:terminate() -> hs.task object
/// Method
/// Terminates the task
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.task` object
///
/// Notes:
///  * This will send SIGTERM to the process
static int task_SIGTERM(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);

    @try {
        [(__bridge NSTask *)userData->nsTask terminate];
    }
    @catch (NSException *exception) {
        printToConsole(L, "hs.task:terminate() called on non-running task");
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.task:interrupt() -> hs.task object
/// Method
/// Interrupts the task
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.task` object
///
/// Notes:
///  * This will send SIGINT to the process
static int task_SIGINT(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);

    @try {
        [(__bridge NSTask *)userData->nsTask interrupt];
    }
    @catch (NSException *exception) {
        printToConsole(L, "hs.task:interrupt() called on non-running task");
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.task:pause() -> boolean
/// Method
/// Pauses the task
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if the task was paused, otherwise false
///
/// Notes:
///  * This method can be called multiple times, but a matching number of `hs.task:resume()` calls will be required to allow the process to continue
static int task_pause(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);
    BOOL result = false;

    @try {
        result = [(__bridge NSTask *)userData->nsTask suspend];
    }
    @catch (NSException *exception) {
        printToConsole(L, "hs.task:pause() called on non-running task");
    }

    lua_pushboolean(L, result);
    return 1;
}

/// hs.task:resume() -> boolean
/// Method
/// Resumes the task
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if the task was resumed, otherwise false
static int task_resumeTask(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);
    BOOL result = false;

    @try {
        result = [(__bridge NSTask *)userData->nsTask resume];
    }
    @catch (NSException *exception) {
        printToConsole(L, "hs.task:resume() called on non-running task");
    }

    lua_pushboolean(L, result);
    return 1;
}

/// hs.task:waitUntilExit() -> hs.task object
/// Method
/// Blocks Hammerspoon until the task exits
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.task` object
///
/// Notes:
///  * All Lua and Hammerspoon activity will be blocked by this method. Its use is highly discouraged.
static int task_block(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);

    [(__bridge NSTask *)userData->nsTask waitUntilExit];

    lua_pushvalue(L, 1);
    return 1;
}

static int task_getEnvironment(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);
    NSTask *task = (__bridge NSTask *)userData->nsTask;

    [skin pushNSObject:task.environment];
    return 1;
}

static int task_setEnvironment(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);
    NSTask *task = (__bridge NSTask *)userData->nsTask;

    task.environment = [skin toNSObjectAtIndex:2];

    return 1;
}

static int task_toString(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    task_userdata_t *userData = lua_touserdata(L, 1);

    [skin pushNSObject:[NSString stringWithFormat:@"hs.task: %@ %@", (__bridge NSString *)userData->launchPath, [(__bridge NSArray *)userData->arguments componentsJoinedByString:@" "]]];
    return 1;
}

static int task_gc(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    task_userdata_t *userData = lua_touserdata(L, 1);
    NSTask *task = (__bridge_transfer NSTask *)userData->nsTask;
    NSPointerArray *pointerArray = pointerArrayFromNSTask(task);

    if (pointerArray) {
        [tasks removeObject:pointerArray];
    }

    task.terminationHandler = ^(NSTask *task){};

    @try {
        [task terminate];
    }
    @catch (NSException *exception) {
        // Nothing to do here
    }
    task = nil;

    userData->luaCallback = [skin luaUnref:refTable ref:userData->luaCallback];

    NSString *launchPath = (__bridge_transfer NSString *)userData->launchPath;
    NSArray *arguments = (__bridge_transfer NSArray *)userData->arguments;

    launchPath = nil;
    arguments = nil;

    return 0;
}

static int task_metagc(lua_State *L) {
    [tasks removeAllObjects];

    return 0;
}

// Lua function definitions
static const luaL_Reg taskLib[] = {
    {"new", task_new},

    {NULL, NULL}
};

static const luaL_Reg taskMetaLib[] = {
    {"__gc", task_metagc},

    {NULL, NULL}
};

static const luaL_Reg taskObjectLib[] = {
    {"environment", task_getEnvironment},
    {"setEnvironment", task_setEnvironment},

    {"pid", task_getPID},

    {"start", task_launch},
    {"terminate", task_SIGTERM},
    {"interrupt", task_SIGINT},
    {"pause", task_pause},
    {"resume", task_resumeTask},

    {"waitUntilExit", task_block},

    {"__gc", task_gc},
    {"__tostring", task_toString},

    {NULL, NULL}
};

int luaopen_hs_task_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG functions:taskLib metaFunctions:taskMetaLib objectFunctions:taskObjectLib];

    tasks = [[NSMutableArray alloc] init];

    return 1;
}
