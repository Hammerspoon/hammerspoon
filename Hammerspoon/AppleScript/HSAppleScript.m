//
//  executeAppleScript.m
//  Hammerspoon
//
//  Created by Chris Hocking on 5/4/17.
//  Copyright © 2017 Hammerspoon. All rights reserved.
//

#import "HSAppleScript.h"
#import "MJLua.h"
#import "variables.h"

@implementation executeAppleScript

-(id)performDefaultImplementation {
    
    // Get the arguments:
    NSDictionary *args = [self evaluatedArguments];
    NSString *stringToExecute = @"";
    if(args.count) {
        stringToExecute = [args valueForKey:@""];    // Get the direct argument
    } else {
        // Raise error:
        [self setScriptErrorNumber:-50];
        [self setScriptErrorString:@"A Parameter is expected for the verb 'execute'. You need to tell Hammerspoon what Lua code you want to execute."];
    }
    
    if (HSAppleScriptEnabled()) {
        // Execute Lua Code:
        MJLuaRunString(stringToExecute);
        return @"Executed Successfully";
    } else {
        // Raise error:
        [self setScriptErrorNumber:-50];
        [self setScriptErrorString:@"Hammerspoon's AppleScript support is currently disabled. Please enable it in Hammerspoon by using the hs.appleScript(true) command."];
        return @"Execution Failed";
    }
}

@end

static void reflect_defaults(void);

void HSAppleScriptSetup(void) {
    reflect_defaults();
}

BOOL HSAppleScriptEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:HSAppleScriptEnabledKey];
}

void HSAppleScriptSetEnabled(BOOL visible) {
    [[NSUserDefaults standardUserDefaults] setBool:visible
                                            forKey:HSAppleScriptEnabledKey];
    reflect_defaults();
}

static void reflect_defaults(void) {
    NSApplication* app = [NSApplication sharedApplication]; // NSApp is typed to 'id'; lame
    NSDisableScreenUpdates();
    [app setActivationPolicy: HSAppleScriptEnabled() ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [app unhide: nil];
        [app activateIgnoringOtherApps:YES];
        NSEnableScreenUpdates();
    });
}
