#import <Cocoa/Cocoa.h>
#import "MJAppDelegate.h"
#import "MJConsoleWindowController.h"
#import "MJPreferencesWindowController.h"
#import "MJDockIcon.h"
#import "MJMenuIcon.h"
#import "MJLua.h"
#import "MJVersionUtils.h"
#import "MJConfigUtils.h"
#import "MJFileUtils.h"
#import "MJAccessibilityUtils.h"
#import "variables.h"
#import "secrets.h"

@implementation MJAppDelegate

static BOOL MJFirstRunForCurrentVersion(void) {
    NSString* key = [NSString stringWithFormat:@"%@_%d", MJHasRunAlreadyKey, MJVersionFromThisApp()];

    BOOL firstRun = ![[NSUserDefaults standardUserDefaults] boolForKey:key];

    if (firstRun)
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:key];

    return firstRun;
}

- (BOOL) applicationShouldHandleReopen:(NSApplication*)theApplication hasVisibleWindows:(BOOL)hasVisibleWindows {
    [[MJConsoleWindowController singleton] showWindow: nil];
    return NO;
}

-(void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    // Set up an early event manager handler so we can catch URLs used to launch us
    NSAppleEventManager *appleEventManager = [NSAppleEventManager sharedAppleEventManager];
    [appleEventManager setEventHandler:self
                           andSelector:@selector(handleGetURLEvent:withReplyEvent:)
                         forEventClass:kInternetEventClass andEventID:kAEGetURL];
    self.startupEvent = nil;
    self.startupFile = nil;
    self.openFileDelegate = nil;
    self.updateAvailable = @NO;
}

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    self.startupEvent = event;
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)fileAndPath {
    NSString *typeOfFile = [[NSWorkspace sharedWorkspace] typeOfFile:fileAndPath error:nil];
    
    if ([typeOfFile isEqualToString:@"org.hammerspoon.hammerspoon.spoon"]) {
        // This is a Spoon, so we will attempt to copy it to the Spoons directory
        NSError *moveError;
        BOOL success = NO;
        NSString *spoonPath = [MJConfigDir() stringByAppendingPathComponent:@"Spoons"];
        NSString *spoonName = [fileAndPath lastPathComponent];
        success = [[NSFileManager defaultManager] moveItemAtPath:fileAndPath toPath:[spoonPath stringByAppendingPathComponent:spoonName] error:&moveError];
        if (!success) {
            NSLog(@"Unable to move %@ to %@: %@", fileAndPath, spoonPath, moveError);
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"OK"];
            [alert setMessageText:@"Error importing Spoon"];
            [alert setInformativeText:[NSString stringWithFormat:@"%@\n\nSource: %@\nDest: %@", moveError.localizedDescription, fileAndPath, spoonPath]];
            [alert setAlertStyle:NSCriticalAlertStyle];
            [alert runModal];
        } else {
            NSUserNotification *notification = [[NSUserNotification alloc] init];
            notification.title = @"Spoon imported";
            notification.informativeText = [NSString stringWithFormat:@"%@ is now available", spoonName];
            notification.soundName = NSUserNotificationDefaultSoundName;
            [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
        }
        return YES; // Note that we always return YES here because otherwise macOS tells the user that we can't open Spoons, which is ludicrous
    }
    
    NSString *fileExtension = [fileAndPath pathExtension];
    NSDictionary *infoDict=[[NSBundle mainBundle] infoDictionary];
    NSArray *supportedExtensions=[infoDict valueForKeyPath:@"CFBundleDocumentTypes.CFBundleTypeExtensions"];
    NSArray *flatSupportedExtensions = [supportedExtensions valueForKeyPath: @"@unionOfArrays.self"];
    
    // Files to be processed by hs.urlevent:
    if([flatSupportedExtensions containsObject:fileExtension]){
        if (!self.openFileDelegate) {
            self.startupFile = fileAndPath;
        } else {
            if ([self.openFileDelegate respondsToSelector:@selector(callbackWithURL:)]) {
                [self.openFileDelegate callbackWithURL:fileAndPath];
            }
        }
    }
    
    // Trigger File Dropped to Dock Icon Callback:
    fileDroppedToDockIcon(fileAndPath);
    
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(accessibilityChanged:) name:@"com.apple.accessibility.api" object:nil];
    
    // Remove our early event manager handler so hs.urlevent can register for it later, if the user has it configured to
    [[NSAppleEventManager sharedAppleEventManager] removeEventHandlerForEventClass:kInternetEventClass andEventID:kAEGetURL];

    if(NSClassFromString(@"XCTest") != nil) {
        // Hammerspoon Tests
        NSLog(@"in testing mode!");
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSBundle *bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:@"%@/Contents/Plugins/Hammerspoon Tests.xctest", mainBundle.bundlePath]];
        NSString *lsUnitPath = [bundle pathForResource:@"lsunit" ofType:@"lua"];
        const char *fsPath = [lsUnitPath fileSystemRepresentation];

        if (!fsPath) {
            NSLog(@"Unable to find lsunit.lua in Hammerspoon Tests.xctest. We're about to crash, sorry!");
            abort();
        } else {
            NSLog(@"testing lsunit.lua");
        }
        MJConfigFile = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:fsPath length:strlen(fsPath)];
    } else if ([[[NSProcessInfo processInfo] environment] objectForKey:@"XCTESTING"]) {
        // Hammerspoon UI Tests
        NSLog(@"in UI testing mode");
        NSString *initPath = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingString:@"/Hammerspoon UI Tests-Runner.app/Contents/PlugIns/Hammerspoon UI Tests.xctest/Contents/Resources/init.lua"];
        const char *fsPath = [initPath fileSystemRepresentation];

        if (!fsPath) {
            NSLog(@"Unable to find init.lua in Hammerspoon UI Tests. We're about to crash, sorry!");
            abort();
        } else {
            NSLog(@"UI testing init.lua");
        }
        MJConfigFile = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:fsPath length:strlen(fsPath)];
        [self showConsoleWindow:nil];
    } else {
        // No test environment detected, this is a live user run
        NSString* userMJConfigFile = [[NSUserDefaults standardUserDefaults] stringForKey:@"MJConfigFile"];
        if (userMJConfigFile) MJConfigFile = userMJConfigFile ;

        // Ensure we have a Spoons directory
        NSString *spoonsPath = [MJConfigDir() stringByAppendingPathComponent:@"Spoons"];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL spoonsPathIsDir;
        BOOL spoonsPathExists = [fileManager fileExistsAtPath:spoonsPath isDirectory:&spoonsPathIsDir];

        NSLog(@"Determined Spoons path will be: %@ (exists: %@, isDir: %@)", spoonsPath, spoonsPathExists ? @"YES" : @"NO", spoonsPathIsDir ? @"YES" : @"NO");

        if (spoonsPathExists && !spoonsPathIsDir) {
            NSLog(@"ERROR: %@ exists, but is a file", spoonsPath);
            abort();
        }

        if (!spoonsPathExists) {
            NSLog(@"Creating Spoons directory at: %@", spoonsPath);
            [[NSFileManager defaultManager] createDirectoryAtPath:spoonsPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }

    // Dragging & Dropping of Text to Dock Item:
    [NSApp setServicesProvider:self];
    
    MJEnsureDirectoryExists(MJConfigDir());
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:MJConfigDir()];

    [self registerDefaultDefaults];

    // Enable Crashlytics, if we have an API key available
#ifdef CRASHLYTICS_API_KEY
    if (HSUploadCrashData()) {
        Crashlytics *crashlytics = [Crashlytics sharedInstance];
        crashlytics.debugMode = YES;
        [Crashlytics startWithAPIKey:[NSString stringWithUTF8String:CRASHLYTICS_API_KEY] delegate:self];
    }
#endif

    // Become the Sparkle delegate, if it's available
    if (NSClassFromString(@"SUUpdater")) {
        NSString *frameworkPath = [[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingPathComponent:@"Sparkle.framework"];
        if ([[NSBundle bundleWithPath:frameworkPath] load]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
            id sharedUpdater = [NSClassFromString(@"SUUpdater")  performSelector:@selector(sharedUpdater)];
            NSMethodSignature * mySignature = [NSClassFromString(@"SUUpdater") instanceMethodSignatureForSelector:@selector(setDelegate:)];
            NSInvocation * myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
            [myInvocation setTarget:sharedUpdater];
            // even though signature specifies this, we need to specify it in the invocation, since the signature is re-usable
            // for any method which accepts the same signature list for the target.
            [myInvocation setSelector:@selector(setDelegate:)];
            [myInvocation setArgument:(void *)&self atIndex:2];
            [myInvocation invoke];
#pragma clang diagnostic pop
        }
    }

    MJMenuIconSetup(self.menuBarMenu);
    MJDockIconSetup();
    [[MJConsoleWindowController singleton] setup];
    MJLuaCreate();

    // FIXME: Do we care about showing the prefs on the first run of each new version? (Ng does not care)
    if (MJFirstRunForCurrentVersion() || !MJAccessibilityIsEnabled())
        [[MJPreferencesWindowController singleton] showWindow: nil];
}

// Dragging & Dropping of Text to Dock Item:
-(void)processDockIconDraggedText:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error {
    NSString * pboardString = [pboard stringForType:NSStringPboardType];
    textDroppedToDockIcon(pboardString);
}

- (void) accessibilityChanged:(NSNotification*)note {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        callAccessibilityStateCallback();
    });
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    MJLuaDestroy();
    return NSTerminateNow;
}

- (void) registerDefaultDefaults {
    [[NSUserDefaults standardUserDefaults]
     registerDefaults: @{@"NSApplicationCrashOnExceptions": @YES,
                         MJShowDockIconKey: @YES,
                         MJShowMenuIconKey: @YES,
                         HSAutoLoadExtensions: @YES,
                         HSUploadCrashDataKey: @YES,
                         }];
}

- (IBAction) reloadConfig:(id)sender {
    MJLuaReplace();
}

- (IBAction) showConsoleWindow:(id)sender {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[MJConsoleWindowController singleton] showWindow: nil];
}

- (IBAction) showPreferencesWindow:(id)sender {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[MJPreferencesWindowController singleton] showWindow: nil];
}

- (IBAction) showAboutPanel:(id)sender {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    @try {
        [[NSApplication sharedApplication] orderFrontStandardAboutPanel: nil];
    } @catch (NSException *exception) {
        [[LuaSkin shared] logError:@"Unable to open About dialog. This may mean your Hammerspoon installation is corrupt. Please re-install it!"];
    }
}

- (IBAction) quitHammerspoon:(id)sender {
    [[NSApplication sharedApplication] terminate:nil];
}

- (IBAction) openConfig:(id)sender {
    NSString* path = MJConfigFileFullPath();

    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createFileAtPath:path
                                                contents:[NSData data]
                                              attributes:nil];
    }

    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    if ([workspace openFile:path] == NO) {
        // No app is associated with .lua files, so fall back on TextEdit
        [workspace openFile:path withApplication:@"TextEdit" andDeactivate:YES];
    }
}

- (void)showMjolnirMigrationNotification {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:@"Hammerspoon crash detected"];
    [alert setInformativeText:@"Your init.lua is loading Mjolnir modules and a previous launch crashed.\n\nHammerspoon ships with updated versions of many of the Mjolnir modules, with both new features and many bug fixes.\n\nPlease consult our API documentation and migrate your config."];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert runModal];
}

- (void)crashlyticsDidDetectReportForLastExecution:(CLSReport *)report completionHandler:(void (^)(BOOL submit))completionHandler {
    BOOL showMjolnirMigrationDialog = NO;

    if ([report.customKeys objectForKey:@"MjolnirModuleLoaded"]) {
        showMjolnirMigrationDialog = YES;
    }

    completionHandler(YES);

    if (showMjolnirMigrationDialog) {
        [self showMjolnirMigrationNotification];
    }
}

#pragma mark - Sparkle delegate methods
- (void)updater:(id)updater didFindValidUpdate:(id)update {
    self.updateAvailable = @YES;
}

- (void)updaterDidNotFindUpdate:(id)update {
    self.updateAvailable = @NO;
}

@end

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}
