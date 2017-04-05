//
//  executeAppleScript.m
//  Hammerspoon
//
//  Created by Chris Hocking on 5/4/17.
//  Copyright © 2017 Hammerspoon. All rights reserved.
//

#import "executeAppleScript.h"
#import "MJLua.h"

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
        [self setScriptErrorString:@"Parameter Error: A Parameter is expected for the verb 'execute'. You need to tell Hammerspoon what Lua code you want to execute."];
    }
    
    // Execute Lua Code:
    return MJLuaRunString(stringToExecute);
}

@end
