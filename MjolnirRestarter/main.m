#import <Cocoa/Cocoa.h>

@interface MJRestartWaiter : NSObject
@end

static MJRestartWaiter* restarter;
static NSString* MJBundlePath;
static pid_t MJParent;

static void MJRelaunch() {
    [[NSWorkspace sharedWorkspace] launchApplication:MJBundlePath];
    exit(0);
}

@implementation MJRestartWaiter
- (void) applicationDidTerminate:(NSNotification*)note {
    if ([[[note userInfo] valueForKey:@"NSApplicationProcessIdentifier"] intValue] == MJParent)
        MJRelaunch();
}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        restarter = [[MJRestartWaiter alloc] init];
        MJBundlePath = [NSString stringWithUTF8String:argv[1]];
        MJParent = atoi(argv[2]);
        if (getppid() == 1) MJRelaunch();
        
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:restarter
                                                               selector:@selector(applicationDidTerminate:)
                                                                   name:NSWorkspaceDidTerminateApplicationNotification
                                                                 object:nil];
        
        [[NSApplication sharedApplication] run];
    }
    return 0;
}
