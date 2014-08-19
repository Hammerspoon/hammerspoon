#import <Cocoa/Cocoa.h>

static NSString* live_app_path;
static NSString* temp_app_path;
static pid_t parent_pid;

static void MJRelaunch() {
    NSLog(@"relaunching...");
    NSLog(@"rm %@", live_app_path);
    NSError* __autoreleasing rmError;
    BOOL rmSuccess = [[NSFileManager defaultManager] removeItemAtPath:live_app_path error:&rmError];
    if (!rmSuccess) {
        NSLog(@"rm failed: %@", [rmError localizedDescription]);
        return;
    }
    
    NSLog(@"cp %@ %@", temp_app_path, live_app_path);
    NSError* __autoreleasing cpError;
    if (![[NSFileManager defaultManager] copyItemAtPath:temp_app_path toPath:live_app_path error:&cpError]) {
        NSLog(@"cp failed: %@", [cpError localizedDescription]);
        return;
    }
    
    NSLog(@"open %@", live_app_path);
    [[NSWorkspace sharedWorkspace] launchApplication:live_app_path];
    exit(0);
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
             pid_t pid = [[[note userInfo] valueForKey:@"NSApplicationProcessIdentifier"] intValue];
             if (pid == parent_pid) {
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
