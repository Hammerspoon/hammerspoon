// DONE:
// * set console mode from cmd line and include in registration
// * allow arbitrary binary from stdin (i.e. don't choke on null in string
// * allow read from file via -f: instead, if arg starts with ./, /, or ~ treat as file and stop parsing args
// * support #! /path/to/hs (if last arg is a file, assume -f?) is there another way to tell?
// * Add -q to suppress `print` in the cli instance
// * optionally save history
// * Decide on legacy mode support... and legacy auto-detection?
// * auto-complete?
// * Add NSTimer to secondary runloop -- it doesn't persist when in legacy mode because nothing is attached to it... this will
//      fix need for trinary op in performSelector at end and auto-reconnect when in legacy mode

// TODO:
//   Document (man page, printUsage, HS docs)
//   verify existing/add new functions to init.lua for tweaking defaults this tool uses

// MAYBE:
//   different color for returned values? Currently uses output color
// * Prompt for launch Hammerspoon?
// *   How do we wait until it's actually running? Since the only check we really have is whether the module is loaded or not
// * flag to suppress prompt?


@import AppKit ;
@import Foundation ;
@import CoreFoundation ;
@import Darwin.sysexits ;
#include <editline/readline.h>

// static NSString          *defaultPortName = @"hsCommandLine" ;
static NSString          *defaultPortName = @"CommandPost" ;
static CFTimeInterval    defaultTimeout   = 4.0 ;
static const CFStringRef hammerspoonBundle = CFSTR("org.latenitefilms.CommandPost") ;

@class HSClient ;

static HSClient          *core = nil ;

#define MSGID_REGISTER   100
#define MSGID_UNREGISTER 200

#define MSGID_LEGACYCHK  900
#define MSGID_COMMAND    500
#define MSGID_QUERY      501

#define MSGID_LEGACY      0    // because it's the only one that version ever sent/used

#define MSGID_ERROR      -1
#define MSGID_OUTPUT      1
#define MSGID_RETURN      2
#define MSGID_CONSOLE     3

@interface HSClient : NSThread
@property CFMessagePortRef localPort ;
@property CFMessagePortRef remotePort ;
@property NSString         *remoteName ;
@property NSString         *localName ;

@property CFTimeInterval   sendTimeout ;
@property CFTimeInterval   recvTimeout ;

@property NSString         *colorBanner ;
@property NSString         *colorInput ;
@property NSString         *colorOutput ;
@property NSString         *colorError ;
@property NSString         *colorReset ;
@property NSArray          *arguments ;

@property BOOL             useColors ;
@property BOOL             autoReconnect ;
@property int              exitCode ;

- (BOOL)registerWithRemote ;
@end

static CFDataRef localPortCallback(__unused CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info) {
    HSClient  *self   = (__bridge HSClient *)info ;

    CFIndex maxSize = CFDataGetLength(data) ;
    char  *responseCString = malloc((size_t)maxSize) ;

    CFDataGetBytes(data, CFRangeMake(0, maxSize), (UInt8 *)responseCString ) ;

    BOOL isStdOut = (msgid < 0) ? NO : YES ;
    NSString *outputColor ;
    switch(msgid) {
        case MSGID_OUTPUT:
        case MSGID_RETURN:  outputColor = self.colorOutput ; break ;
        case MSGID_CONSOLE: outputColor = self.colorBanner ; break ;
        case MSGID_ERROR:
        default:            outputColor = self.colorError ;
    }
    fprintf((isStdOut ? stdout : stderr), "%s", outputColor.UTF8String) ;
    fwrite(responseCString, 1, (size_t)maxSize, (isStdOut ? stdout : stderr)) ;
    fprintf((isStdOut ? stdout : stderr), "%s", self.colorReset.UTF8String) ;
//     fprintf((isStdOut ? stdout : stderr), "\n") ;

    // if the main thread is stuck waiting for readline to complete, the active display color
    // should be the input color; any other output will set it's color before showing text, so
    // this would end up being a noop
    if (msgid == MSGID_CONSOLE) printf("%s", self.colorInput.UTF8String) ;

    free(responseCString) ;

    return CFStringCreateExternalRepresentation(NULL, CFSTR("check"), kCFStringEncodingUTF8, 0) ; ;
}

static const char *portError(SInt32 code) {
    const char* errstr = "unknown error" ;
    switch (code) {
        case kCFMessagePortSendTimeout:        errstr = "send timeout" ; break ;
        case kCFMessagePortReceiveTimeout:     errstr = "receive timeout" ; break ;
        case kCFMessagePortIsInvalid:          errstr = "message port invalid" ; break ;
        case kCFMessagePortTransportError:     errstr = "error during transport" ; break ;
        case kCFMessagePortBecameInvalidError: errstr = "message port was invalidated" ; break ;
    }
    return errstr ;
}

@implementation HSClient

- (instancetype)initWithRemote:(NSString *)remoteName inColor:(BOOL)inColor {
    self = [super init] ;
    if (self) {
        _remotePort    = NULL ;
        _localPort     = NULL ;
        _remoteName    = remoteName ;
        _localName     = [[NSUUID UUID] UUIDString] ;

        _useColors     = inColor ; [self updateColorStrings] ;

        _arguments     = nil ;
        _sendTimeout   = 4.0 ;
        _recvTimeout   = 4.0 ;
        _exitCode      = EX_TEMPFAIL ; // until the thread is actually ready
        _autoReconnect = NO ;
    }
    return self ;
}

- (void)dealloc {
    if (_localPort) {
        CFMessagePortInvalidate(_localPort) ;
        CFRelease(_localPort) ;
    }
    if (_remotePort) {
        CFRelease(_remotePort) ;
    }
}

- (void)main {
    @autoreleasepool {
        _remotePort = CFMessagePortCreateRemote(NULL, (__bridge CFStringRef)_remoteName) ;
        if (!_remotePort) {
            fprintf(stderr, "error: can't access CommandPost message port %s; is it running with the ipc module loaded?\n", _remoteName.UTF8String) ;
            _exitCode = EX_UNAVAILABLE ;
            [self cancel] ;
            return ;
        }
        // legacy mode check. If the remotePort does not respond with a version string to this msgID, then it's not
        // the official `hs.ipc` handler so fall back to legacy mode -- i.e. we don't setup our own remotePort for
        // asynchronous bidirectional communication
        NSString *answer = [[NSString alloc] initWithData:[self sendToRemote:@"1 + 1" msgID:MSGID_LEGACYCHK wantResponse:YES error:nil]
                                                 encoding:NSUTF8StringEncoding] ;
        if ([answer hasPrefix:@"version:"]) {
            CFMessagePortContext ctx = { 0, (__bridge void *)self, NULL, NULL, NULL } ;
            Boolean error = false ;
            _localPort = CFMessagePortCreateLocal(NULL, (__bridge CFStringRef)_localName, localPortCallback, &ctx, &error) ;

            if (error) {
                NSString *errorMsg = _localPort ? [NSString stringWithFormat:@"%@ port name already in use", _localName] : @"failed to create new local port" ;
                fprintf(stderr, "error: %s\n", errorMsg.UTF8String) ;
                _exitCode = EX_UNAVAILABLE ;
                [self cancel] ;
                return ;
            }

            CFRunLoopSourceRef runLoop = CFMessagePortCreateRunLoopSource(NULL, _localPort, 0) ;
            if (runLoop) {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoop, kCFRunLoopCommonModes) ;
                CFRelease(runLoop) ;
            } else {
                fprintf(stderr, "unable to create runloop source for local port\n") ;
                _exitCode = EX_UNAVAILABLE ;
                [self cancel] ;
                return ;
            }
        }

        if ([self registerWithRemote]) {
            NSTimer *keepAlive = [NSTimer timerWithTimeInterval:2.0 target:self selector:@selector(checkRemoteConnection:) userInfo:nil repeats:YES] ;
            [[NSRunLoop currentRunLoop] addTimer:keepAlive forMode:NSDefaultRunLoopMode] ;

            BOOL keepRunning = YES ;
            _exitCode = EX_OK ;
            while(keepRunning && ([[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]])) {
                if (_exitCode != EX_OK)  {
                    keepRunning = NO ;
                } else {
                    keepRunning = ![self isCancelled] ;
                }
            }
            [self unregisterWithRemote] ;
            if (keepAlive.valid) [keepAlive invalidate] ;
        } else {
            _exitCode = EX_UNAVAILABLE ;
            [self cancel] ;
            return ;
        }
    } ;
}

- (void)checkRemoteConnection:(NSTimer *)timer {
    if (!CFMessagePortIsValid(_remotePort) && _autoReconnect) {
        fprintf(stderr, "Message port has become invalid.  Attempting to re-establish.\n") ;
        CFMessagePortRef newPort = NULL ;
        NSUInteger count = 0 ;
        while (!newPort && count < 5) {
            sleep(2) ;
            newPort = CFMessagePortCreateRemote(NULL, (__bridge CFStringRef)_remoteName) ;
            if (newPort) {
                CFRelease(_remotePort) ;
                _remotePort = newPort ;
                if ([self registerWithRemote]) fprintf(stderr, "Re-established.\n") ;
            } else {
                count++ ;
            }
        }
        if (!newPort) {
            fprintf(stderr, "error: can't access CommandPost; is it running?\n") ;
            _exitCode = EX_UNAVAILABLE ;
            [self cancel] ;
            [self performSelector:@selector(poke:) onThread:self withObject:nil waitUntilDone:NO] ;
            if (timer.valid) [timer invalidate] ;
        }
    }
}

- (void)poke:(__unused id)obj {
    // do nothing but allows an external performSelector:onThread: to break the runloop
}

- (void)updateColorStrings {
    if (_useColors) {
        CFStringRef initial = CFPreferencesCopyAppValue(CFSTR("ipc.cli.color_initial"), hammerspoonBundle) ;
        CFStringRef input   = CFPreferencesCopyAppValue(CFSTR("ipc.cli.color_input"),   hammerspoonBundle) ;
        CFStringRef output  = CFPreferencesCopyAppValue(CFSTR("ipc.cli.color_output"),  hammerspoonBundle) ;
        CFStringRef error   = CFPreferencesCopyAppValue(CFSTR("ipc.cli.color_error"),   hammerspoonBundle) ;
        _colorBanner = initial ? (__bridge_transfer NSString *)initial : @"\033[35m" ;
        _colorInput  = input   ? (__bridge_transfer NSString *)input   : @"\033[33m" ;
        _colorOutput = output  ? (__bridge_transfer NSString *)output  : @"\033[36m" ;
        _colorError  = error   ? (__bridge_transfer NSString *)error   : @"\033[31m" ;
        _colorReset = @"\033[0m" ;
    } else {
        _colorReset  = @"" ;
        _colorBanner = @"" ;
        _colorInput  = @"" ;
        _colorOutput = @"" ;
        _colorError  = @"" ;
    }
}

- (NSData *)sendToRemote:(id)data msgID:(SInt32)msgid wantResponse:(BOOL)wantResponse error:(NSError * __autoreleasing *)error {
    NSMutableData *dataToSend = [NSMutableData data] ;
    if (msgid == MSGID_COMMAND || (msgid == MSGID_QUERY && _localPort)) {
        // prepend our UUID so the receiving callback knows which instance to communicate with
        NSData *prefix = [[NSString stringWithFormat:@"%@\0", _localName] dataUsingEncoding:NSUTF8StringEncoding] ;
        [dataToSend appendData:prefix] ;
    } else if (msgid == MSGID_LEGACY || (msgid == MSGID_QUERY && !_localPort)) {
        char j = 'x' ; // we're not bothering with raw mode until/unless someone complains... and maybe not even then
        [dataToSend appendData:[NSData dataWithBytes:&j length:1]] ;
    }
    if (data) {
        NSData *actualMessage = [data isKindOfClass:[NSData class]] ? data : [[data description] dataUsingEncoding:NSUTF8StringEncoding] ;
        if (actualMessage) [dataToSend appendData:actualMessage] ;
    }

    CFDataRef returnedData ;
    SInt32 code = CFMessagePortSendRequest(
                                              _remotePort,
                                              msgid,
                                              (__bridge CFDataRef)dataToSend,
                                              _sendTimeout,
                                              (wantResponse ? _recvTimeout : 0.0),
                                              (wantResponse ? kCFRunLoopDefaultMode : NULL),
                                              &returnedData
                                          ) ;

    if (code != kCFMessagePortSuccess) {
        if (error) {
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:code userInfo:nil] ;
        } else {
            fprintf(stderr, "error sending to remote: %s\n", portError(code)) ;
        }
        return nil ;
    }

    NSData *resultData = nil ;
    if (wantResponse) {
        resultData = returnedData ? (__bridge_transfer NSData *)returnedData : nil ;
    }
    return resultData ;
}

- (BOOL)registerWithRemote {
    if (_localPort) { // not needed for legacy mode
        NSString *registration = _localName ;
        if (_arguments) {
            NSError* error ;
            NSData* data = [NSJSONSerialization dataWithJSONObject:_arguments options:(NSJSONWritingOptions)0 error:&error] ;
            if (!error && data) {
                NSString* str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ;
                registration = [NSString stringWithFormat:@"%@\0%@", _localName, str] ;
            } else {
                fprintf(stderr, "unable to serialize arguments for registration: %s\n", error.localizedDescription.UTF8String) ;
            }
        }

        NSError *error = nil ;
        [self sendToRemote:registration msgID:MSGID_REGISTER wantResponse:YES error:&error] ;
        if (error) {
            fprintf(stderr, "error registering CLI instance with CommandPost: %s\n", portError((SInt32)error.code)) ;
            return NO ;
        }
    }
    return YES ;
}

- (BOOL)unregisterWithRemote {
    if (_localPort) { // not needed for legacy mode
        NSError *error = nil ;
        [self sendToRemote:_localName msgID:MSGID_UNREGISTER wantResponse:NO error:&error] ;
        if (error) {
            fprintf(stderr, "error unregistering CLI instance with CommandPost: %s (transport errors are normal if Hammerspoon is reloading)\n", portError((SInt32)error.code)) ;
            return NO ;
        }
    }
    return YES ;
}

- (BOOL)executeCommand:(id)command {
    NSError *error ;
    NSData *response = [self sendToRemote:command msgID:(_localPort ? MSGID_COMMAND : MSGID_LEGACY) wantResponse:YES error:&error] ;
    if (error) {
        fprintf(stderr, "error communicating with CommandPost: %s\n", portError((SInt32)error.code)) ;
        _exitCode = EX_UNAVAILABLE ;
        return NO ;
    } else {
        if (_localPort) {
            NSString *answer = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding] ;
//             return [answer isEqualToString:@"+ok"] ;
            return [answer isEqualToString:@"ok"] ;
        } else {
            // LEGACY OUTPUT HERE
            NSUInteger maxSize = response.length ;
            char  *responseCString = malloc((size_t)maxSize) ;
            [response getBytes:responseCString length:maxSize] ;

            fprintf(stdout, "%s", _colorOutput.UTF8String) ;
            fwrite(responseCString, 1, (size_t)maxSize, stdout) ;
            fprintf(stdout, "%s", _colorOutput.UTF8String) ;
            fprintf(stdout, "\n") ;

            free(responseCString) ;
            return YES ;
        }
    }
}

@end

static char *dupstr (const char* s) {
  char *r;

  r = (char*) malloc ((strlen (s) + 1));
  strcpy (r, s);
  return (r);
}

static char *hs_completion_generator(const char* text, int state) {
    static NSUInteger index  = 0 ;
    static NSArray    *items = nil ;

    if (!state) {
        index = 0 ;
        items = nil ;
        NSError *error = nil ;
        NSData  *results = [core sendToRemote:[NSString stringWithFormat:@"require(\"hs.json\").encode(hs.completionsForInputString(\"%s\"))", text] msgID:MSGID_QUERY wantResponse:YES error:&error] ;
        if (error) {
            fprintf(stderr, "error getting completion list: %s\n", portError((SInt32)error.code)) ;
            return ((char *)NULL) ;
        } else {
            items = [NSJSONSerialization JSONObjectWithData:results options:NSJSONReadingAllowFragments error:&error] ;
            if (error) {
                items = nil ;
                fprintf(stderr, "error interpreting completion results: %s (input == %s)\n", error.localizedDescription.UTF8String, [[NSString alloc] initWithData:results encoding:NSUTF8StringEncoding].UTF8String) ;
                return ((char *)NULL) ;
            } else if (![items isKindOfClass:[NSArray class]]) {
                items = nil ;
                fprintf(stderr, "invalid response for completion list: %s\n", items.description.UTF8String) ;
                return ((char *)NULL) ;
            }
        }
    }

    if (items && index < items.count) {
        NSString *answer = items[index] ;
        index++ ;

        // the generator function must return a copy of the string since ARC will clear the NSString
        return dupstr(answer.UTF8String) ;
    } else {
        return ((char *)NULL) ;
    }
}

static char** hs_completion(const char * text , __unused int start,  __unused int end) {
// we want our completion handler no matter where we are in the line
    rl_attempted_completion_over   = 1 ;
    return rl_completion_matches ((const char*)text, &hs_completion_generator) ;
}

static void printUsage(const char *cmd) {
    printf("\n") ;
    printf("usage: %s [arguments] [file]\n", cmd) ;
    printf("\n") ;
    printf("    -A         Auto launch CommandPost if it is not currently running.  The default behavior is to prompt the user for confirmation before launching.\n") ;
    printf("    -c cmd     Specifies a CommandPost command to execute. May be specified more than once and commands will be executed in the order they appear. Disables colorized output unless -N is present. Disables interactive mode unless -i is present. If -i is present or if stdin is a pipe, these commands will be executed first.\n") ;
    printf("    -C         Enable print cloning from the CommandPost Console to this instance. Disables -P.\n") ;
    printf("    -h         Displays this help and exits.\n") ;
    printf("    -i         Enable interactive mode. Default unless -c argument is present, stdin is a pipe, output is redirected, or if a file path is specified.\n") ;
    printf("    -m name    Specify the name of the remote port to connect to. Defaults to %s.\n", defaultPortName.UTF8String) ;
    printf("    -n         Disable colorized output. Automatic if stdin is a pipe, output is redirected, or if a file path is specified.\n") ;
    printf("    -N         Force colorized output even when it would normally not be enabled.\n") ;
    printf("    -P         Enable print mirroring from this instance to the CommandPost Console. Disables -C.\n") ;
    printf("    -q         Enable quiet mode.  In quiet mode, the only output to the instance will be errors and the final result of any command executed.\n") ;
    printf("    -s         Read stdin for the contents to execute and exit.  Included for backwards compatibility as this tool now detects when stdin is a pipe automatically. Disables colorized output unless -N is present. Disables interactive mode.\n") ;
    printf("    -t sec     Specifies the send and receive timeouts in seconds.  Defaults to %f seconds.\n", defaultTimeout) ;
    printf("    --         Ignore all arguments following, allowing custom arguments to be passed into the cli instance.\n") ;
    printf("    /path/file Specifies a file containing CommandPost code to load and execute. Must start with  ~, ./, or / and be a file readable by the user.  Disables colorized output unless -N is present.  Disables interactive mode unless -i is present. Like --, all arguments after this are passed in unparsed.\n") ;
    printf("\n") ;
    printf("Within the instance, all arguments passed to the %s executable are available as strings in the `_cli._args` array.  If the -- argument or a file path is present, that argument and all arguments that follow will be available as strings in the `_cli.args` array; otherwise the `_cli.args` array will be a mirror of `_cli._args`.\n", cmd) ;
    printf("\n") ;
}

void sigint_handler(__unused int signo) __attribute__((__noreturn__)) ;
void sigint_handler(__unused int signo) {
    printf("\033[0m") ;
    exit(4) ;
}

int main()
{
    int exitCode = 0 ;
    signal(SIGINT, sigint_handler) ;

    @autoreleasepool {

        BOOL           readStdIn   = (BOOL)!isatty(STDIN_FILENO) ;
        BOOL           readFile    = NO ;
        BOOL           interactive = !readStdIn && (BOOL)isatty(STDOUT_FILENO) ;
        BOOL           useColors   = interactive ;
        BOOL           autoLaunch  = NO ;
        NSString       *portName   = defaultPortName ;
        NSString       *fileName   = nil ;

        CFTimeInterval timeout     = defaultTimeout ;

        NSMutableArray<NSString *> *preRun     = nil ;

        NSArray<NSString *> *args = [[NSProcessInfo processInfo] arguments] ;
        NSUInteger idx   = 1 ; // skip command name

        BOOL seenColors      = NO ;
        BOOL seenInteractive = NO ;

        while(idx < args.count) {
            NSString *errorMsg = nil ;

            if ([args[idx] isEqualToString:@"-i"]) {
                readStdIn       = NO ;
                interactive     = YES ;
                seenInteractive = YES ;
// Not really necessary, except maybe for backwards compatibility?
            } else if ([args[idx] isEqualToString:@"-s"]) {
                interactive = NO ;
                readStdIn   = YES ;
                if (!seenColors) useColors = NO ;
            } else if ([args[idx] isEqualToString:@"-A"]) {
                autoLaunch = YES ;
            } else if ([args[idx] isEqualToString:@"-n"]) {
                useColors = NO ;
            } else if ([args[idx] isEqualToString:@"-N"]) {
                useColors  = YES ;
                seenColors = YES ;
            } else if ([args[idx] isEqualToString:@"-C"]) {
                // silently ignore -- it's parsed in the handler
            } else if ([args[idx] isEqualToString:@"-P"]) {
                // silently ignore -- it's parsed in the handler
            } else if ([args[idx] isEqualToString:@"-q"]) {
                // silently ignore -- it's parsed in the handler
            } else if ([args[idx] isEqualToString:@"-m"]) {
                if ((idx + 1) < args.count) {
                    idx++ ;
                    portName = args[idx] ;
                } else {
                    errorMsg = @"option requires an argument" ;
                }
            } else if ([args[idx] isEqualToString:@"-c"]) {
                if (!preRun) preRun = [[NSMutableArray alloc] init] ;
                if ((idx + 1) < args.count) {
                    idx++ ;
                    preRun[preRun.count] = args[idx] ;
                    if (!seenColors)      useColors   = NO ;
                    if (!seenInteractive) interactive = NO ;
                } else {
                    errorMsg = @"option requires an argument" ;
                }
            } else if ([args[idx] isEqualToString:@"-t"]) {
                if ((idx + 1) < args.count) {
                    idx++ ;
                    timeout = [args[idx] doubleValue] ;
                } else {
                    errorMsg = @"option requires an argument" ;
                }
            } else if ([args[idx] isEqualToString:@"-h"] || [args[idx] isEqualToString:@"-?"]) {
                printUsage(args[0].UTF8String) ;
                exit(EX_OK) ;
            } else if ([args[idx] isEqualToString:@"--"]) {
                break ; // remaining arguments are to be passed in as is
            } else if ([args[idx] hasPrefix:@"~"] || [args[idx] hasPrefix:@"./"] || [args[idx] hasPrefix:@"/"]) {
                fileName = [args[idx] stringByExpandingTildeInPath] ;
                if (access(fileName.UTF8String, R_OK) == 0) {
                    readFile  = YES ;
                    readStdIn = NO ; // maybe capture and save as _cli.stdin?
                    if (!seenColors)      useColors   = NO ;
                    if (!seenInteractive) interactive = NO ;
                    break ; // remaining arguments are to be passed in as is
                } else {
                    errorMsg = [NSString stringWithFormat:@"%s", strerror(errno)] ;
                }
            } else {
                errorMsg = @"illegal option" ;
            }

            if (errorMsg) {
                fprintf(stderr, "%s: %s: %s\n", args[0].UTF8String, errorMsg.UTF8String, args[idx].UTF8String) ;
                exit(EX_USAGE) ;
            }
            idx++ ;
        }


        NSArray *ra = [NSRunningApplication runningApplicationsWithBundleIdentifier:(__bridge NSString *)hammerspoonBundle] ;
        if (ra.count == 0) {
            BOOL launchHS = autoLaunch ;
            if (!autoLaunch) {
                NSAlert *alert = [[NSAlert alloc] init] ;
                [alert addButtonWithTitle:@"Launch"] ;
                [alert addButtonWithTitle:@"Cancel"] ;
                alert.messageText = @"CommandPost is not running" ;
                alert.informativeText = @"CommandPost is not running. Would you like to launch it now?" ;
                NSString *imagePath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:(__bridge NSString *)hammerspoonBundle];
                alert.icon = [[NSWorkspace sharedWorkspace] iconForFile:imagePath] ;
                alert.alertStyle = NSAlertStyleCritical ;
                NSModalResponse response = [alert runModal] ;
                if (response != NSAlertFirstButtonReturn) exit(EX_UNAVAILABLE) ;
                launchHS = YES ;
                // necessary to clear the alert from the screen; otherwise it persists until you hit enter in the terminal window
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]] ;

            }
            if (launchHS && ![[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:(__bridge NSString *)hammerspoonBundle options:NSWorkspaceLaunchWithoutActivation additionalEventParamDescriptor:nil launchIdentifier:NULL]) exit(EX_UNAVAILABLE) ;

            NSUInteger count = 0 ;
            BOOL       notReady = YES ;
            while (notReady && count < 10) {
                CFMessagePortRef test = CFMessagePortCreateRemote(NULL, (__bridge CFStringRef)portName) ;
                if (test) {
                    notReady = NO ;
                    CFRelease(test) ;
                }
                sleep(1) ;
                count++ ;
            }
            if (notReady) {
                fprintf(stderr, "error: can't access CommandPost message port %s; is it running with the ipc module loaded?\n", portName.UTF8String) ;
                exit(EX_UNAVAILABLE) ;
            }
        }

        core = [[HSClient alloc] initWithRemote:portName inColor:useColors] ;

        // during stdin, file, and preRun commands, we want a disconnect to error out
        core.autoReconnect = NO ;

        // may split them up later...
        core.sendTimeout = timeout ;
        core.recvTimeout = timeout ;

        core.arguments   = args ;

        [core start] ;

        while (core.exitCode == EX_TEMPFAIL) ;

        if (core.exitCode == EX_OK && !core.localPort)
            fprintf(stderr, "%s-- Legacy mode enabled --%s\n", core.colorBanner.UTF8String, core.colorReset.UTF8String) ;

        if (core.exitCode == EX_OK && preRun) {
            for (NSString *command in preRun) {
                BOOL status = [core executeCommand:command] ;
                if (!status) {
                    if (core.exitCode == EX_OK) core.exitCode = EX_DATAERR ;
                    break ;
                }
            }
        }

        if (core.exitCode == EX_OK && readStdIn) {
            NSMutableData *command = [[NSMutableData alloc] init] ;
            char buffer[BUFSIZ] ;
            size_t readLength ;
            while((readLength = fread(buffer, 1, BUFSIZ, stdin)) > 0) {
                [command appendBytes:buffer length:readLength] ;
            }

            if (ferror(stdin)) {
                perror("error reading from stdin:") ;
                core.exitCode = EX_NOINPUT ;
            } else {
                BOOL status = [core executeCommand:command] ;
                if (!status) {
                    if (core.exitCode == EX_OK) core.exitCode = EX_DATAERR ;
                }
            }
        }

        if (core.exitCode == EX_OK && readFile) {
            FILE *fp = fopen(fileName.UTF8String, "r") ;
            if (fp) {
                NSMutableData *file = [[NSMutableData alloc] init] ;
                char buffer[BUFSIZ] ;
                size_t readLength ;
                while((readLength = fread(buffer, 1, BUFSIZ, fp)) > 0) {
                    [file appendBytes:buffer length:readLength] ;
                }

                if (ferror(fp)) {
                    perror("error reading from file:") ;
                    core.exitCode = EX_NOINPUT ;
                } else {
                    char shebang[2] ;
                    [file getBytes:&shebang length:2] ;
                    if (shebang[0] == '#' && shebang[1] == '!') {
                        NSUInteger position = 1 ;
                        while ((position < file.length) && (shebang[0] != '\n') && (shebang[0] != '\r')) {
                            position++ ;
                            [file getBytes:&shebang range:NSMakeRange(position, 1)] ;
                        }
                        if (position < file.length) {
                            file = [[file subdataWithRange:NSMakeRange(position, file.length - position)] mutableCopy] ;
                        } // else give up and let it cause an error
                    }
                    BOOL status = [core executeCommand:file] ;
                    if (!status) {
                        if (core.exitCode == EX_OK) core.exitCode = EX_DATAERR ;
                    }
                }
                fclose(fp) ;
            } else {
                perror("error openning file:") ;
                core.exitCode = EX_NOINPUT ;
            }
        }

        if (core.exitCode == EX_OK && interactive) {
            // but in interactive mode, attempt to reconnect on remote port invalidation
            core.autoReconnect = YES ;


            CFNumberRef CFsaveHistory = CFPreferencesCopyAppValue(CFSTR("ipc.cli.saveHistory"), hammerspoonBundle) ;
            BOOL saveHistory = CFsaveHistory ? [(__bridge_transfer NSNumber *)CFsaveHistory boolValue] : NO ;

            CFNumberRef CFhistoryLimit = CFPreferencesCopyAppValue(CFSTR("ipc.cli.historyLimit"), hammerspoonBundle) ;
            int  historyLimit = CFhistoryLimit ? [(__bridge_transfer NSNumber *)CFhistoryLimit intValue] : 1000 ;

            CFStringRef CFhsDir   = CFPreferencesCopyAppValue(CFSTR("MJConfigFile"), hammerspoonBundle) ;
            NSString    *confFile = CFhsDir ? (__bridge_transfer NSString *)CFhsDir : @"~/.hammerspoon/init.lua" ;
            confFile = [[confFile substringToIndex:(confFile.length - 8)] stringByAppendingFormat:@".cli.history"] ;
            confFile = confFile.stringByExpandingTildeInPath ;

            if (saveHistory) read_history(confFile.UTF8String) ;

            printf("%sCommandPost interactive prompt.%s\n", core.colorBanner.UTF8String, core.colorReset.UTF8String) ;

            rl_attempted_completion_function = hs_completion ;
            rl_completion_append_character = '\0' ; // no space after completion

            while (core.exitCode == EX_OK) {
                printf("\n%s", core.colorInput.UTF8String) ;
                char* input = readline("> ") ;
                printf("%s", core.colorReset.UTF8String) ;
                if (!input) { // ctrl-d or other issue with readline
                    printf("\n") ;
                    break ;
                }

                if (*input) add_history(input) ; // don't save empty lines

                if (core.exitCode == EX_OK) [core executeCommand:[NSString stringWithCString:input encoding:NSUTF8StringEncoding]] ;

                if (input) free(input) ;
            }

            if (saveHistory) write_history(confFile.UTF8String) ;
            if (saveHistory) history_truncate_file (confFile.UTF8String, historyLimit) ;

        }

        if (core.remotePort && !core.cancelled) {
            [core cancel] ;
            // cancel does not break the runloop, so poke it to wake it up
            [core performSelector:@selector(poke:) onThread:core withObject:nil waitUntilDone:YES] ;
        }
        exitCode = core.exitCode ;
        core = nil ;
    } ;
    return(exitCode) ;
}
