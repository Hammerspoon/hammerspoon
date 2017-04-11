//
//  HSAppleScript.h
//  Hammerspoon
//
//  Created by Chris Hocking on 5/4/17.
//  Copyright © 2017 Hammerspoon. All rights reserved.
//

#import <Foundation/Foundation.h>

//
// Enable & Disable AppleScript Support:
//
BOOL HSAppleScriptEnabled(void);
void HSAppleScriptSetEnabled(BOOL enabled);

//
// Execute Lua Code:
//
@interface executeLua : NSScriptCommand {
}
- (id)performDefaultImplementation;
@end

//
// Open Hammerspoon Console:
//
@interface openHammerspoonConsole : NSScriptCommand {
}
- (id)performDefaultImplementation;
@end

//
// Open Hammerspoon Preferences:
//
@interface openHammerspoonPreferences : NSScriptCommand {
}
- (id)performDefaultImplementation;
@end

//
// Dock Icon Value:
//
@interface NSApplication (ScriptingPlugin)

- (NSNumber *)dockIconVisible;
    
@end
