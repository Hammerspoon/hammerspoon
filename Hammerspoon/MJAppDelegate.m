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
#import "HSLogger.h"
#import "variables.h"
#import "secrets.h"

@implementation MJAppDelegate

- (BOOL) applicationShouldHandleReopen:(NSApplication*)theApplication hasVisibleWindows:(BOOL)hasVisibleWindows {
    callDockIconCallback();
    if (HSOpenConsoleOnDockClickEnabled()) {
        [[MJConsoleWindowController singleton] showWindow: nil];
    };
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
    self.updateAvailable = nil;
}

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    self.startupEvent = event;
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)fileAndPath {
    NSString *typeOfFile = [[NSWorkspace sharedWorkspace] typeOfFile:fileAndPath error:nil];

    if ([typeOfFile isEqualToString:@"org.hammerspoon.hammerspoon.spoon"]) {
        // This is a Spoon, so we will attempt to copy it to the Spoons directory
        NSError *fileError;
        BOOL success = NO;
        BOOL upgrade = NO;
        NSString *spoonPath = [MJConfigDir() stringByAppendingPathComponent:@"Spoons"];
        NSString *spoonName = [fileAndPath lastPathComponent];
        NSString *dstSpoonFullPath = [spoonPath stringByAppendingPathComponent:spoonName];
        NSFileManager *fileManager = [NSFileManager defaultManager];

        // Remove any pre-existing copy of the Spoon
        if ([fileManager fileExistsAtPath:dstSpoonFullPath]) {
            NSLog(@"Spoon already exists at %@, removing the old version", dstSpoonFullPath);
            upgrade = YES;
            success = [fileManager removeItemAtPath:dstSpoonFullPath error:&fileError];
            if (!success) {
                NSLog(@"Unable to remove existing Spoon (%@):%@", dstSpoonFullPath, fileError);
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"Error upgrading Spoon"];
                [alert setInformativeText:[NSString stringWithFormat:@"%@\n\nSource: %@\nDest: %@", fileError.localizedDescription, fileAndPath, spoonPath]];
                [alert setAlertStyle:NSCriticalAlertStyle];
                [alert runModal];
                return YES;
            }
        }

        success = [[NSFileManager defaultManager] moveItemAtPath:fileAndPath toPath:dstSpoonFullPath error:&fileError];
        if (!success) {
            NSLog(@"Unable to move %@ to %@: %@", fileAndPath, spoonPath, fileError);
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"OK"];
            [alert setMessageText:@"Error installing Spoon"];
            [alert setInformativeText:[NSString stringWithFormat:@"%@\n\nSource: %@\nDest: %@", fileError.localizedDescription, fileAndPath, spoonPath]];
            [alert setAlertStyle:NSCriticalAlertStyle];
            [alert runModal];
        } else {
            NSUserNotification *notification = [[NSUserNotification alloc] init];
            notification.title = [NSString stringWithFormat:@"Spoon %@", upgrade ? @"upgraded" : @"installed"];
            notification.informativeText = [NSString stringWithFormat:@"%@ is now available%@", spoonName, upgrade ? @", reload your config" : @""];
            notification.soundName = NSUserNotificationDefaultSoundName;
            [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
        }
        return YES; // Note that we always return YES here because otherwise macOS tells the user that we can't open Spoons, which is ludicrous
    }

    NSString *fileExtension = [fileAndPath pathExtension];
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSArray *supportedExtensions = [infoDict valueForKeyPath:@"CFBundleDocumentTypes.CFBundleTypeExtensions"];
    NSArray *flatSupportedExtensions = [supportedExtensions valueForKeyPath:@"@unionOfArrays.self"];

    // Files to be processed by hs.urlevent
    if ([flatSupportedExtensions containsObject:fileExtension]) {
        if (!self.openFileDelegate) {
            self.startupFile = fileAndPath;
        } else {
            if ([self.openFileDelegate respondsToSelector:@selector(callbackWithURL:)]) {
                [self.openFileDelegate callbackWithURL:fileAndPath];
            }
        }
    } else {
        // Trigger File Dropped to Dock Icon Callback
        fileDroppedToDockIcon(fileAndPath);
    }

    return YES;
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    // User is holding down Command (0x37) & Option (0x3A) keys:
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,0x3A) && CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,0x37)) {
        
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Continue"];
        [alert addButtonWithTitle:@"Delete Preferences"];
        [alert setMessageText:@"Do you want to delete the preferences?"];
        [alert setInformativeText:@"Deleting the preferences will reset all Hammerspoon settings (including everything that uses hs.settings) to their defaults."];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        if ([alert runModal] == NSAlertSecondButtonReturn) {
            
            // Reset Preferences:
            NSDictionary * allObjects;
            allObjects = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
            for(NSString *key in allObjects)
            {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey: key];
            }
            [[NSUserDefaults standardUserDefaults] synchronize];
            
        }
    }
    
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

    // Become the handler for events from macOS Services
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

    if (!MJAccessibilityIsEnabled())
        [[MJPreferencesWindowController singleton] showWindow: nil];
}

// Dragging & Dropping of Text to Dock Item
-(void) processDockIconDraggedText:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error {
    NSString *pboardString = [pboard stringForType:NSStringPboardType];
    textDroppedToDockIcon(pboardString);
}

// Dragging & Dropping of File to Dock Item
-(void) processDockIconDraggedFile:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error {
    NSArray *filePaths = [pboard propertyListForType:NSFilenamesPboardType];
    for (NSString *filePath in filePaths) {
        fileDroppedToDockIcon(filePath);
    }
}

- (void) accessibilityChanged:(NSNotification*)note {
    HSNSLOG(@"accessibilityChanged: %@", MJAccessibilityIsEnabled() ? @"ENABLED" : @"DISABLED");
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
                         HSAppleScriptEnabledKey: @NO,
                         HSOpenConsoleOnDockClickKey: @YES,
                         HSPreferencesDarkModeKey: @NO,
                         HSConsoleDarkModeKey: @NO,
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
    NSLog(@"Update found: %@", [update valueForKey:@"versionString"]);
    self.updateAvailable = [update valueForKey:@"versionString"];
}

- (void)updaterDidNotFindUpdate:(id)update {
    self.updateAvailable = nil;
}

@end

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}
