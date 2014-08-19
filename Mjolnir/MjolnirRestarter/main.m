#import <Cocoa/Cocoa.h>

@interface MJRestartWaiter : NSObject
@end

static MJRestartWaiter* restarter;
static NSString* live_app_path;
static NSString* temp_app_path;
static pid_t parent_pid;

static void MJRelaunch() {
    NSError* __autoreleasing rmError;
    BOOL rmSuccess = [[NSFileManager defaultManager] removeItemAtPath:live_app_path error:&rmError];
    if (!rmSuccess) {
        NSLog(@"rm failed: %@", [rmError localizedDescription]);
        return;
    }
    
    NSError* __autoreleasing cpError;
    if ([[NSFileManager defaultManager] copyItemAtPath:temp_app_path toPath:live_app_path error:&cpError]) {
        NSLog(@"cp failed: %@", [cpError localizedDescription]);
        return;
    }
    
    [[NSWorkspace sharedWorkspace] launchApplication:live_app_path];
    exit(0);
}

@implementation MJRestartWaiter

- (void) applicationDidTerminate:(NSNotification*)note {
    if ([[[note userInfo] valueForKey:@"NSApplicationProcessIdentifier"] intValue] == parent_pid)
        MJRelaunch();
}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        parent_pid = atoi(argv[1]);
        live_app_path = [NSString stringWithUTF8String:argv[2]];
        temp_app_path = [NSString stringWithUTF8String:argv[3]];
        restarter = [[MJRestartWaiter alloc] init];
        
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:restarter
                                                               selector:@selector(applicationDidTerminate:)
                                                                   name:NSWorkspaceDidTerminateApplicationNotification
                                                                 object:nil];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (getppid() == 1) {
                MJRelaunch();
            }
        });
        
        dispatch_main();
    }
    return 0;
}
