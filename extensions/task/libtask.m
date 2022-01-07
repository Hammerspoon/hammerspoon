#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG "hs.task"

typedef struct _task_userdata_t {
    void *nsTask;
    bool isStream;
    bool hasStarted ;
    bool hasTerminated;
    int luaCallback;
    int luaStreamCallback;
    void *launchPath;
    void *arguments;
    void *inputData;
    int selfRef;
} task_userdata_t;

static LSRefTable refTable;
NSMutableArray *tasks;
id fileReadObserver; // This maybe ought to be __block __weak, but that's not allowed on global variables

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

task_userdata_t *userDataFromNSFileHandle(NSFileHandle *fh) {
    task_userdata_t *result = NULL;

    for (NSPointerArray *pointerArray in tasks) {
        NSTask *task = (__bridge NSTask *)[pointerArray pointerAtIndex:0];

        NSPipe *stdOut = task.standardOutput;
        NSPipe *stdErr = task.standardError;
        NSPipe *stdIn = task.standardInput;

        NSFileHandle *stdOutFH = [stdOut fileHandleForReading];
        NSFileHandle *stdErrFH = [stdErr fileHandleForReading];
        NSFileHandle *stdInFH = [stdIn fileHandleForWriting];

        if (stdOutFH == fh || stdErrFH == fh || stdInFH == fh) {
            result = [pointerArray pointerAtIndex:1];
        }
    }

    return result;
}

void (^writerBlock)(NSFileHandle *) = ^(NSFileHandle *stdInFH) {
    dispatch_sync(dispatch_get_main_queue(), ^{
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];

        // There don't ever seem to be any circumstances where we want to be called multiple times, so let's immediately prevent ourselves being called again
        stdInFH.writeabilityHandler = nil;

        task_userdata_t *userData = userDataFromNSFileHandle(stdInFH);
        if (!userData) {
            [skin logBreadcrumb:@"ERROR: Unable to get userData in writerBlock"];
            return;
        }

        if (!userData->inputData) {
            [skin logBreadcrumb:@"ERROR: in writerBlock without any data to write"];
            return;
        }

        id inputData = (__bridge_transfer id)userData->inputData;
        userData->inputData = nil;

        @try {
            if ([inputData isKindOfClass:[NSData class]]) {
                [stdInFH writeData:inputData];
            } else {
                [stdInFH writeData:[inputData dataUsingEncoding:NSUTF8StringEncoding]];
            }
        }
        @catch (NSException *exception) {
            [skin logWarn:@"Exception while writing to hs.task handle"];
        }

        // If we're not a streaming task, we can close the file handle now
        if (!userData->isStream) {
            [stdInFH closeFile];
        }
    });
};

void create_task(task_userdata_t *userData) {
    NSTask *task = [[NSTask alloc] init];
    NSPipe *stdOut = [NSPipe pipe];
    NSPipe *stdErr = [NSPipe pipe];
    NSPipe *stdIn = [NSPipe pipe];

    userData->nsTask = (__bridge_retained void*)task;
    task.standardOutput = stdOut;
    task.standardError = stdErr;
    task.standardInput = stdIn;

    task.launchPath = (__bridge NSString *)userData->launchPath;
    task.arguments = (__bridge NSArray *)userData->arguments;
    task.terminationHandler = ^(NSTask *task){
        // Ensure this callback happens on the main thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            task_userdata_t *userData = NULL;
            LuaSkin *skin = [LuaSkin sharedWithState:NULL];
            _lua_stackguard_entry(skin.L);

            NSFileHandle *stdOutFH = [task.standardOutput fileHandleForReading];
            NSFileHandle *stdErrFH = [task.standardError fileHandleForReading];
            NSFileHandle *stdInFH = [task.standardInput fileHandleForWriting];

            NSString *stdOut = nil;
            NSString *stdErr = nil;

            @try {
                stdOut = [[NSString alloc] initWithData:[stdOutFH readDataToEndOfFile] encoding:NSUTF8StringEncoding];
                stdErr = [[NSString alloc] initWithData:[stdErrFH readDataToEndOfFile] encoding:NSUTF8StringEncoding];
            } @catch (NSException *exception) {
                [skin logWarn:[NSString stringWithFormat:@"hs.task terminationHandler block encountered an exception: %@", exception.description]];
            } @finally {
                [stdOutFH closeFile];
                [stdErrFH closeFile];
            }

            userData = userDataFromNSTask(task);

            if (!userData) {
                NSLog(@"NSTask terminationHandler called on a task we don't recognise. This was likely a stuck process, or one that didn't respond to SIGTERM, and we have already GC'd its objects. Ignoring");
                _lua_stackguard_exit(skin.L);
                return;
            }

            userData->hasTerminated = YES;

            // We only need to close stdin on streaming tasks, all other situations have been handled already
            if (userData->isStream) {
                [stdInFH closeFile];
            }

            if (userData->luaCallback != LUA_NOREF && userData->luaCallback != LUA_REFNIL) {
                [skin pushLuaRef:refTable ref:userData->luaCallback];
                lua_pushinteger(skin.L, task.terminationStatus);
                [skin pushNSObject:stdOut];
                [skin pushNSObject:stdErr];
                [skin protectedCallAndError:@"hs.task callback" nargs:3 nresults:0];
            }
            userData->selfRef = [skin luaUnref:refTable ref:userData->selfRef];
            _lua_stackguard_exit(skin.L);
        });
    };

    return;
}

/// hs.task.new(launchPath, callbackFn[, streamCallbackFn][, arguments]) -> hs.task object
/// Function
/// Creates a new hs.task object
///
/// Parameters:
///  * launchPath - A string containing the path to an executable file.  This must be the full path to an executable and not just an executable which is in your environment's path (e.g. `/bin/ls` rather than just `ls`).
///  * callbackFn - A callback function to be called when the task terminates, or nil if no callback should be called. The function should accept three arguments:
///   * exitCode - An integer containing the exit code of the process
///   * stdOut - A string containing the standard output of the process
///   * stdErr - A string containing the standard error output of the process
///  * streamCallbackFn - A optional callback function to be called whenever the task outputs data to stdout or stderr. The function must return a boolean value - true to continue calling the streaming callback, false to stop calling it. The function should accept three arguments:
///   * task - The hs.task object or nil if this is the final output of the completed task.
///   * stdOut - A string containing the standard output received since the last call to this callback
///   * stdErr - A string containing the standard error output received since the last call to this callback
///  * arguments - An optional table of command line argument strings for the executable
///
/// Returns:
///  * An `hs.task` object
///
/// Notes:
///  * The arguments are not processed via a shell, so you do not need to do any quoting or escaping. They are passed to the executable exactly as provided.
///  * When using a stream callback, the callback may be invoked one last time after the termination callback has already been invoked. In this case, the `task` argument to the stream callback will be `nil` rather than the task userdata object and the return value of the stream callback will be ignored.
static int task_new(lua_State *L) {
    // Check our arguments
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TFUNCTION|LS_TNIL, LS_TTABLE|LS_TFUNCTION|LS_TOPTIONAL, LS_TTABLE|LS_TOPTIONAL, LS_TBREAK];

    // Create our Lua userdata object
    task_userdata_t *userData = lua_newuserdata(L, sizeof(task_userdata_t));
    memset(userData, 0, sizeof(task_userdata_t));
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    lua_pushvalue(L, -1);
    userData->selfRef = [skin luaRef:refTable];

    // Capture data in the Lua userdata object
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        userData->luaCallback = [skin luaRef:refTable];
    } else {
        userData->luaCallback = LUA_REFNIL;
    }

    if (lua_type(L, 3) == LUA_TFUNCTION) {
        lua_pushvalue(L, 3);
        userData->luaStreamCallback = [skin luaRef:refTable];
        userData->isStream = YES;
    } else {
        userData->luaStreamCallback = LUA_REFNIL;
        userData->isStream = NO;
    }

    userData->hasStarted = NO ;
    userData->hasTerminated = NO;
    userData->launchPath = (__bridge_retained void *)[skin toNSObjectAtIndex:1];
    userData->inputData = nil;

    if (lua_type(L, 3) == LUA_TTABLE) {
        userData->arguments = (__bridge_retained void *)[skin toNSObjectAtIndex:3];
    } else if (lua_type(L, 4) == LUA_TTABLE) {
        userData->arguments = (__bridge_retained void *)[skin toNSObjectAtIndex:4];
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
/// Set or remove a callback function for a task.
///
/// Parameters:
///  * fn - A function to be called when the task completes or is terminated, or nil to remove an existing callback
///
/// Returns:
///  * the hs.task object
static int task_setCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);

    userData->luaCallback = [skin luaUnref:refTable ref:userData->luaCallback];
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        userData->luaCallback = [skin luaRef:refTable];
    }

    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.task:setInput(inputData) -> hs.task object
/// Method
/// Sets the standard input data for a task
///
/// Parameters:
///  * inputData - Data, in string form, to pass to the task as its standard input
///
/// Returns:
///  * The hs.task object
///
/// Notes:
///  * This method can be called before the task has been started, to prepare some input for it (particularly if it is not a streaming task)
///  * If this method is called multiple times, any input that has not been passed to the task already, is discarded (for streaming tasks, the data is generally consumed very quickly, but for now there is no way to syncronise this)
static int task_setInput(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER, LS_TBREAK];

    task_userdata_t *userData = lua_touserdata(L, 1);

    if (!userData->hasTerminated) {
        NSTask *task = (__bridge NSTask *)userData->nsTask;
        NSPipe *stdIn = task.standardInput;
        NSFileHandle *stdInFH = stdIn.fileHandleForWriting;

        // Force numerical input to be rendered to a string
        luaL_checkstring(L, 2);

        // Discard any previous input data
        if (userData->inputData) {
            id oldData = (__bridge_transfer id)userData->inputData;
            oldData = nil;
            userData->inputData = nil;
        }

        // Store input data
        userData->inputData = (__bridge_retained void *)[skin toNSObjectAtIndex:2 withOptions:LS_NSPreserveLuaStringExactly];
        stdInFH.writeabilityHandler = writerBlock;
    } else {
        [skin logWarn:@"hs.task:setInput() called on a task that has already terminated"];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.task:closeInput() -> hs.task object
/// Method
/// Closes the task's stdin
///
/// Parameters:
///  * None
///
/// Returns:
///  * The hs.task object
///
/// Notes:
///  * This should only be called on tasks with a streaming callback - tasks without it will automatically close stdin when any data supplied via `hs.task:setInput()` has been written
///  * This is primarily useful for sending EOF to long-running tasks
static int task_closeInput(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    task_userdata_t *userData = lua_touserdata(L, 1);
    NSTask *task = (__bridge NSTask *)userData->nsTask;

    NSPipe *stdIn = task.standardInput;
    NSFileHandle *stdInFH = stdIn.fileHandleForWriting;
    [stdInFH closeFile];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.task:setStreamingCallback(fn) -> hs.task object
/// Method
/// Set a stream callback function for a task
///
/// Parameters:
///  * fn - A function to be called when the task outputs to stdout or stderr, or nil to remove a callback
///
/// Returns:
///  * The hs.task object
///
/// Notes:
///  * For information about the requirements of the callback function, see `hs.task.new()`
///  * If a callback is removed without it previously having returned false, any further stdout/stderr output from the task will be silently discarded
static int task_setStreamingCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);

    userData->luaStreamCallback = [skin luaUnref:refTable ref:userData->luaStreamCallback];
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        userData->luaStreamCallback = [skin luaRef:refTable];
    }

    lua_pushvalue(L, 1);
    return 1;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);
    NSTask *task = (__bridge NSTask *)userData->nsTask;
    NSString *thePath = [skin toNSObjectAtIndex:2] ;

    @try {
        [task setCurrentDirectoryPath:thePath] ;
        lua_pushvalue(L, 1) ;
    }
    @catch (NSException *exception) {
        [skin logWarn:[NSString stringWithFormat:@"hs.task:setWorkingDirectory() Unable to set the working directory for task: %@", exception.reason]];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);
    BOOL result = false;

    @try {
        NSTask *task = (__bridge NSTask *)userData->nsTask;
        NSPipe *stdIn = task.standardInput;
        NSFileHandle *stdInFH = [stdIn fileHandleForWriting];

        if (userData->isStream == NO && !userData->inputData) {
            [stdInFH closeFile];
        }

        [task launch];
        result = true;
        userData->hasStarted = YES ;

        if (userData->isStream) {
            NSPipe *stdOut = task.standardOutput;
            NSPipe *stdErr = task.standardError;

            NSFileHandle *stdOutFH = [stdOut fileHandleForReading];
            NSFileHandle *stdErrFH = [stdErr fileHandleForReading];

            [stdOutFH readInBackgroundAndNotify];
            [stdErrFH readInBackgroundAndNotify];
        }
    }
    @catch (NSException *exception) {
        [skin logWarn:[NSString stringWithFormat:@"hs.task:launch() Unable to launch hs.task process: %@", exception.reason]];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);

    @try {
        [(__bridge NSTask *)userData->nsTask terminate];
    }
    @catch (NSException *exception) {
        [skin logWarn:[NSString stringWithFormat:@"hs.task:terminate() Unable to terminate hs.task process: %@", exception.reason]];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);

    @try {
        [(__bridge NSTask *)userData->nsTask interrupt];
    }
    @catch (NSException *exception) {
        [skin logWarn:[NSString stringWithFormat:@"hs.task:interrupt() Unable to interrupt hs.task process: %@", exception.reason]];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);
    BOOL result = false;

    @try {
        result = [(__bridge NSTask *)userData->nsTask suspend];
    }
    @catch (NSException *exception) {
        [skin logWarn:[NSString stringWithFormat:@"hs.task:pause() Unable to pause hs.task process: %@", exception.reason]];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);
    BOOL result = false;

    @try {
        result = [(__bridge NSTask *)userData->nsTask resume];
    }
    @catch (NSException *exception) {
        [skin logWarn:[NSString stringWithFormat:@"hs.task:resue() Unable to resume hs.task process: %@", exception.reason]];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
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
            [skin logWarn:[NSString stringWithFormat:@"hs.task:terminationStatus() Unable to get termination status for hs.task process: %@", exception.reason]];
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
    [[LuaSkin sharedWithState:L] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
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
            [skin logWarn:[NSString stringWithFormat:@"hs.task:terminationReason() Unable to get terminations tatus for hs.task process: %@", exception.reason]];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK];
    task_userdata_t *userData = lua_touserdata(L, 1);
    NSTask *task = (__bridge NSTask *)userData->nsTask;

    @try {
        task.environment = [skin toNSObjectAtIndex:2];
        lua_pushvalue(L, 1) ;
    }
    @catch (NSException *exception) {
        [skin logWarn:[NSString stringWithFormat:@"hs.task:setEnvironment() Unable to set environment: %@", exception.reason]];
        lua_pushboolean(L, NO) ;
    }

    return 1;
}

static int task_toString(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    task_userdata_t *userData = lua_touserdata(L, 1);

    [skin pushNSObject:[NSString stringWithFormat:@"hs.task: %@ %@ (%p)", (__bridge NSString *)userData->launchPath, [(__bridge NSArray *)userData->arguments componentsJoinedByString:@" "], lua_topointer(L, 1)]];
    return 1;
}

static int task_gc(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
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
    userData->selfRef = [skin luaUnref:refTable ref:userData->selfRef];
    userData->luaStreamCallback = [skin luaUnref:refTable ref:userData->luaStreamCallback];

    NSString *launchPath = (__bridge_transfer NSString *)userData->launchPath;
    NSArray *arguments = (__bridge_transfer NSArray *)userData->arguments;

    launchPath = nil;
    arguments = nil;

    return 0;
}

static int task_metagc(__unused lua_State *L) {
    [tasks removeAllObjects];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:fileReadObserver];

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
    {"setStreamingCallback", task_setStreamingCallback},
    {"setInput", task_setInput},
    {"closeInput", task_closeInput},

    {"waitUntilExit", task_block},

    {"__gc", task_gc},
    {"__tostring", task_toString},

    {NULL, NULL}
};

int luaopen_hs_libtask(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG functions:taskLib metaFunctions:taskMetaLib objectFunctions:taskObjectLib];

    tasks = [[NSMutableArray alloc] init];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    fileReadObserver = [nc addObserverForName:NSFileHandleReadCompletionNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        NSFileHandle *fh = [note object];
        NSData *fhData = [[note userInfo] objectForKey:NSFileHandleNotificationDataItem];

        if ([fhData length] == 0) {
            return;
        }

        NSString *dataString = [[NSString alloc] initWithData:fhData encoding:NSUTF8StringEncoding];

        task_userdata_t *userData = userDataFromNSFileHandle(fh);

        if (!userData) {
            [skin logWarn:@"hs.task received output data from an unknown task. This may be a bug"];
            return;
        }

        if (userData->luaStreamCallback != LUA_NOREF && userData->luaStreamCallback != LUA_REFNIL) {
            LuaSkin *_skin = [LuaSkin sharedWithState:NULL];
            lua_State *_L = _skin.L;
            _lua_stackguard_entry(_L);
            NSFileHandle *stdOutFH = [((__bridge NSTask *)userData->nsTask).standardOutput fileHandleForReading];
            NSFileHandle *stdErrFH = [((__bridge NSTask *)userData->nsTask).standardError fileHandleForReading];

            id stdOutArg = @"";
            id stdErrArg = @"";

            if (fh == stdOutFH) {
                stdOutArg = dataString;
            } else if (fh == stdErrFH) {
                stdErrArg = dataString;
            } else {
                [_skin logError:@"hs.task:setStreamingCallback() Received data from an unknown file handle"];
                _lua_stackguard_exit(_L);
                return;
            }

            BOOL notLastGasp = (userData->selfRef != LUA_NOREF && userData->selfRef != LUA_REFNIL) ;
            [_skin pushLuaRef:refTable ref:userData->luaStreamCallback];
            if (notLastGasp) {
                [_skin pushLuaRef:refTable ref:userData->selfRef];
            } else {
                lua_pushnil(L) ;
            }
            [_skin pushNSObject:stdOutArg];
            [_skin pushNSObject:stdErrArg];

            if (![_skin protectedCallAndTraceback:3 nresults:1]) {
                const char *errorMsg = lua_tostring([_skin L], -1);
                [_skin logError:[NSString stringWithFormat:@"hs.task:setStreamingCallback() callback error: %s", errorMsg]];
                // No lua_pop() here, it's handled below
            }

            if (lua_type(_L, -1) != LUA_TBOOLEAN) {
                [_skin logError:@"hs.task:setStreamingCallback() callback did not return a boolean"];
            } else {
                BOOL continueStreaming = lua_toboolean(_L, -1);

                // there is nothing to stream further if this was invoked *after* the termination handler
                // and an exception may be thrown, so let's just skip the readInBackgroundAndNotify instead...
                if (continueStreaming && notLastGasp) {
                    @try {
                        [fh readInBackgroundAndNotify];
                    } @catch (NSException *exception) {
                        [_skin logError:[NSString stringWithFormat:@"hs.task:setStreamingCallback() post-callback background reading threw an exception. Please file a bug saying: %@", exception.description]];
                    } @finally {
                        ;
                    }
                }
            }
            lua_pop(_L, 1); // result or error
            _lua_stackguard_exit(_L);
        }

    }];

    return 1;
}
