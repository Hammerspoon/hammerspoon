#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

#define USERDATA_TAG "hs.task"

typedef struct _task_userdata_t {
    void *nsTask;
    bool hasStarted ;
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

            NSFileHandle *stdOutFH = [task.standardOutput fileHandleForReading];
            NSFileHandle *stdErrFH = [task.standardError fileHandleForReading];

            NSString *stdOut = [[NSString alloc] initWithData:[stdOutFH readDataToEndOfFile] encoding:NSUTF8StringEncoding];
            NSString *stdErr = [[NSString alloc] initWithData:[stdErrFH readDataToEndOfFile] encoding:NSUTF8StringEncoding];

            [stdOutFH closeFile];
            [stdErrFH closeFile];

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

                if (![skin protectedCallAndTraceback:3 nresults:0]) {
                    const char *errorMsg = lua_tostring([skin L], -1);
                    CLS_NSLOG(@"%s", errorMsg);
                    showError([skin L], (char *)errorMsg);
                }
//                 [skin protectedCallAndTraceback:3 nresults:0];
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
///  * launchPath - A string containing the path to an executable file.  This must be the full path to an executable and not just an executable which is in your environment's path (e.g. `/bin/ls` rather than just `ls`).
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

    userData->hasStarted = NO ;
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

/// hs.task:setCallback(fn) -> hs.task object
/// Method
/// Set or change a callback function for a task.
///
/// Paramaters:
///  * fn - the function to be called when the task completes or is terminated, or an explicit nil if you wish to remove an existing callback.
///
/// Returns:
///  * the hs.task object
static int task_setCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);

    userData->luaCallback = [skin luaUnref:refTable ref:userData->luaCallback];
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        userData->luaCallback = [skin luaRef:refTable];
    } else {
        userData->luaCallback = LUA_REFNIL;
    }

    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.task:workingDirectory() -> path
/// Method
/// Returns the working directory for the task.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string containing the working directory for the task.
///
/// Notes:
///  * This only returns the directory that the task starts in.  If the task changes the directory itself, this value will not reflect that change.
static int task_getWorkingDirectory(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);
    NSTask *task = (__bridge NSTask *)userData->nsTask;

    [skin pushNSObject:task.currentDirectoryPath];
    return 1;
}

/// hs.task:setWorkingDirectory(path) -> hs.task object | false
/// Method
/// Sets the working directory for the task.
///
/// Parameters:
///  * path - a string containing the path you wish to be the working directory for the task.
///
/// Returns:
///  * The hs.task object, or false if the working directory was not set (usually because the task is already running or has completed)
///
/// Notes:
///  * You can only set the working directory if the task has not already been started.
///  * This will only set the directory that the task starts in.  The task itself can change the directory while it is running.
static int task_setWorkingDirectory(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);
    NSTask *task = (__bridge NSTask *)userData->nsTask;
    NSString *thePath = [skin toNSObjectAtIndex:2] ;

    @try {
        [task setCurrentDirectoryPath:thePath] ;
        lua_pushvalue(L, 1) ;
    }
    @catch (NSException *exception) {
        printToConsole(L, "hs.task:setWorkingDirectory() Unable to set the working directory for task:");
        printToConsole(L, (char *)[exception.reason UTF8String]);
        lua_pushboolean(L, NO) ;
    }

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

/// hs.task:start() -> hs.task object | false
/// Method
/// Starts the task
///
/// Parameters:
///  * None
///
/// Returns:
///  *  If the task was started successfully, returns the task object; otherwise returns false
///
/// Notes:
///  * If the task does not start successfully, the error message will be printed to the Hammerspoon Console
static int task_launch(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);
    BOOL result = false;

    @try {
        [(__bridge NSTask *)userData->nsTask launch];
        result = true;
        userData->hasStarted = YES ;
    }
    @catch (NSException *exception) {
        printToConsole(skin.L, "ERROR: Unable to launch hs.task process:");
        printToConsole(skin.L, (char *)[exception.reason UTF8String]);
    }

    if (result)
        lua_pushvalue(L, 1) ;
    else
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
        printToConsole(L, "hs.task:terminate() Unable to terminate hs.task process:");
        printToConsole(skin.L, (char *)[exception.reason UTF8String]);
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
        printToConsole(L, "hs.task:interrupt() Unable to interrupt hs.task process:");
        printToConsole(skin.L, (char *)[exception.reason UTF8String]);
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
///  *  If the task was paused successfully, returns the task object; otherwise returns false
///
/// Notes:
///  * If the task is not paused, the error message will be printed to the Hammerspoon Console
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
        printToConsole(L, "hs.task:pause() Unable to pause hs.task process:");
        printToConsole(L, (char *)[exception.reason UTF8String]);
    }

    if (result)
        lua_pushvalue(L, 1) ;
    else
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
///  *  If the task was resumed successfully, returns the task object; otherwise returns false
///
/// Notes:
///  * If the task is not resumed successfully, the error message will be printed to the Hammerspoon Console
static int task_resumeTask(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);
    BOOL result = false;

    @try {
        result = [(__bridge NSTask *)userData->nsTask resume];
    }
    @catch (NSException *exception) {
        printToConsole(L, "hs.task:resume() Unable to resume hs.task process:");
        printToConsole(L, (char *)[exception.reason UTF8String]);
    }

    if (result)
        lua_pushvalue(L, 1) ;
    else
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


/// hs.task:terminationStatus() -> exitCode | false
/// Method
/// Returns the termination status of a task, or false if the task is still running.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the numeric exitCode of the task, or the boolean false if the task has not yet exited (either because it has not yet been started or because it is still running).
static int task_terminationStatus(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);
    @try {
        lua_pushinteger(L, [(__bridge NSTask *)userData->nsTask terminationStatus]) ;
    }
    @catch (NSException *exception) {
//         if ([[exception name] isEqualToString:NSInvalidArgumentException])
//             lua_pushboolean(L, NO) ;
//         else
//             return luaL_error(L, "terminationStatus:unhandled exception: %s", [[exception name] UTF8String]) ;

// Follow existing convention for module instead...
        lua_pushboolean(L, NO) ;
        if (![[exception name] isEqualToString:NSInvalidArgumentException]) {
            printToConsole(L, "hs.task:terminationStatus() Unable get termination status for hs.task process:");
            printToConsole(L, (char *)[exception.reason UTF8String]);
        }
    }
    return 1 ;
}

/// hs.task:isRunning() -> boolean
/// Method
/// Test if a task is still running.
///
/// Parameters:
///  * None
///
/// Returns:
///  * true if the task is running or false if it is not.
///
/// Notes:
///  * A task which has not yet been started yet will also return false.
static int task_isRunning(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);
    if (!userData->hasStarted)
        lua_pushboolean(L, NO) ;
    else {
        lua_pushcfunction(L, task_terminationStatus) ;
        lua_pushvalue(L, 1) ;
        lua_call(L, 1, 1) ;
        lua_pushboolean(L, (lua_type(L, -1) == LUA_TNUMBER) ? NO : YES) ;
        lua_remove(L, -2) ;
    }
    return 1 ;
}

/// hs.task:terminationReason() -> exitCode | false
/// Method
/// Returns the termination reason for a task, or false if the task is still running.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string value of "exit" if the process exited normally or "interrupt" if it was killed by a signal.  Returns false if the termination reason is unavailable (the task is still running, or has not yet been started).
static int task_terminationReason(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);
    @try {
        switch([(__bridge NSTask *)userData->nsTask terminationReason]) {
            case NSTaskTerminationReasonExit:           lua_pushstring(L, "exit") ;     break ;
            case NSTaskTerminationReasonUncaughtSignal: lua_pushstring(L, "interrupt") ; break ;
            default:                                    lua_pushstring(L, "unknown") ;  break ;
        }
    }
    @catch (NSException *exception) {
//         if ([[exception name] isEqualToString:NSInvalidArgumentException])
//             lua_pushboolean(L, NO) ;
//         else
//             return luaL_error(L, "terminationReason:unhandled exception: %s", [[exception name] UTF8String]) ;

// Follow existing convention for module instead...
        lua_pushboolean(L, NO) ;
        if (![[exception name] isEqualToString:NSInvalidArgumentException]) {
            printToConsole(L, "hs.task:terminationReason() Unable get termination status for hs.task process:");
            printToConsole(L, (char *)[exception.reason UTF8String]);
        }
    }
    return 1 ;
}

/// hs.task:environment() -> environment
/// Method
/// Returns the environment variables as a table for the task.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table of the environment variables for the task where each key is the environment variable name.
///
/// Note:
///  * if you have not yet set an environment table with the `hs.task:setEnvironment` method, this method will return a copy of the Hammerspoon environment table, as this is what the task will inherit by default.
static int task_getEnvironment(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);
    NSTask *task = (__bridge NSTask *)userData->nsTask;

    if (task.environment)
        [skin pushNSObject:task.environment];
    else
        [skin pushNSObject:[[NSProcessInfo processInfo] environment]] ;
    return 1;
}

/// hs.task:setEnvironment(environment) -> hs.task object | false
/// Method
/// Sets the environment variables for the task.
///
/// Parameters:
///  * environment - a table of key-value pairs representing the environment variables that will be set for the task.
///
/// Returns:
///  * The hs.task object, or false if the table was not set (usually because the task is already running or has completed)
///
/// Note:
///  * If you do not set an environment table with this method, the task will inherit the environment variables of the Hammerspoon application.  Set this to an empty table if you wish for no variables to be set for the task.
static int task_setEnvironment(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);
    NSTask *task = (__bridge NSTask *)userData->nsTask;

    @try {
        task.environment = [skin toNSObjectAtIndex:2];
        lua_pushvalue(L, 1) ;
    }
    @catch (NSException *exception) {
        printToConsole(L, "hs.task:setEnvironment() Unable to set environment:");
        printToConsole(L, (char *)[exception.reason UTF8String]);
        lua_pushboolean(L, NO) ;
    }

    return 1;
}

static int task_toString(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    task_userdata_t *userData = lua_touserdata(L, 1);

    [skin pushNSObject:[NSString stringWithFormat:@"hs.task: %@ %@ (%p)", (__bridge NSString *)userData->launchPath, [(__bridge NSArray *)userData->arguments componentsJoinedByString:@" "], lua_topointer(L, 1)]];
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

    task.terminationHandler = ^(__unused NSTask *task){};

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

static int task_metagc(__unused lua_State *L) {
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
    {"terminationStatus", task_terminationStatus},
    {"terminationReason", task_terminationReason},
    {"isRunning", task_isRunning},
    {"setWorkingDirectory", task_setWorkingDirectory},
    {"workingDirectory", task_getWorkingDirectory},
    {"setCallback", task_setCallback},

    {"waitUntilExit", task_block},

    {"__gc", task_gc},
    {"__tostring", task_toString},

    {NULL, NULL}
};

int luaopen_hs_task_internal(__unused lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG functions:taskLib metaFunctions:taskMetaLib objectFunctions:taskObjectLib];

    tasks = [[NSMutableArray alloc] init];

    return 1;
}
