#import <Cocoa/Cocoa.h>

static NSString* live_app_path;
static NSString* temp_app_path;
static pid_t parent_pid;

static void MJShowError(NSString* command, NSString* error) {
    NSAlert* alert = [[NSAlert alloc] init];
    [alert setAlertStyle: NSCriticalAlertStyle];
    [alert setMessageText:@"Error installing Mjolnir update"];
    [alert setInformativeText:[NSString stringWithFormat:@"Command that failed: %@\n\nError: %@", command, error]];
    [alert runModal];
}

static void MJOpenLiveApp(void) {
    [[NSWorkspace sharedWorkspace] launchApplication:live_app_path];
    exit(0);
}

static void MJRelaunch(void) {
    NSError* __autoreleasing rmError;
    BOOL rmSuccess = [[NSFileManager defaultManager] removeItemAtPath:live_app_path error:&rmError];
    if (!rmSuccess) {
        MJShowError([NSString stringWithFormat:@"rm %@", live_app_path], [rmError localizedDescription]);
        MJOpenLiveApp();
    }
    
    NSError* __autoreleasing cpError;
    if (![[NSFileManager defaultManager] copyItemAtPath:temp_app_path toPath:live_app_path error:&cpError]) {
        MJShowError([NSString stringWithFormat:@"cp %@ %@", temp_app_path, live_app_path], [cpError localizedDescription]);
        exit(1);
    }
    
    MJOpenLiveApp();
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        parent_pid = atoi(argv[1]);
        live_app_path = [NSString stringWithUTF8String:argv[2]];
        temp_app_path = [NSString stringWithUTF8String:argv[3]];
        
        [[[NSWorkspace sharedWorkspace] notificationCenter]
         addObserverForName:NSWorkspaceDidTerminateApplicationNotification
         object:nil
         queue:[NSOperationQueue mainQueue]
         usingBlock:^(NSNotification *note) {
             NSRunningApplication* app = [[note userInfo] valueForKey:NSWorkspaceApplicationKey];
             if ([app processIdentifier] == parent_pid) {
                 MJRelaunch();
             }
         }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (getppid() == 1) {
                MJRelaunch();
            }
        });
        
        dispatch_main();
    }
    return 0;
}
