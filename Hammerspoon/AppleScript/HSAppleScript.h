//
//  executeAppleScript.h
//  Hammerspoon
//
//  Created by Chris Hocking on 5/4/17.
//  Copyright © 2017 Hammerspoon. All rights reserved.
//

#import <Foundation/Foundation.h>

void HSAppleScriptSetup(void);
BOOL HSAppleScriptEnabled(void);
void HSAppleScriptSetEnabled(BOOL enabled);

@interface executeAppleScript : NSScriptCommand

@end
