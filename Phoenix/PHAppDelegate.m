//
//  PHAppDelegate.m
//  Phoenix
//
//  Created by Steven on 11/30/13.
//  Copyright (c) 2013 Steven. All rights reserved.
//

#import "PHAppDelegate.h"

#import <JavaScriptCore/JavaScriptCore.h>

#import "PHHotKey.h"

#import "SDWindow.h"

#import "SDUniversalAccessHelper.h"
#import "SDOpenAtLogin.h"

@implementation PHAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
//    PHHotKey* key = [PHHotKey withKey:@"w" mods:@[] handler:^BOOL(PHHotKey* hotKey) {
//        NSLog(@"hi");
//        NSLog(@"%@", hotKey);
//        [hotKey disable];
//        return NO;
//    }];
//    
//    [key enable];
    
    NSImage* img = [NSImage imageNamed:@"statusitem"];
    [img setTemplate:YES];
    
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self.statusItem setHighlightMode:YES];
    [self.statusItem setImage:img];
    [self.statusItem setMenu:self.statusItemMenu];
    
    
    
    
    
    [SDUniversalAccessHelper complainIfNeeded];
    
    
    JSContext* ctx = [[JSContext alloc] initWithVirtualMachine:[[JSVirtualMachine alloc] init]];
    
    NSURL* _jsURL = [[NSBundle mainBundle] URLForResource:@"underscore-min" withExtension:@"js"];
    NSString* _js = [NSString stringWithContentsOfURL:_jsURL encoding:NSUTF8StringEncoding error:NULL];
    [ctx evaluateScript:_js];
    
    
    
    
//    ctx[@"foo"] = [JSValue valueWithObject:[[Foo alloc] init] inContext:ctx];
    
//    JSValue* x = [ctx evaluateScript:@"(function(){ return 7; });"];
//    NSLog(@"%@", [x callWithArguments:@[]]);
    
    
    
    ctx[@"HotKey"] = [PHHotKey self];
    
    NSLog(@"%@", [[ctx evaluateScript:@"HotKey"] toObject]);
    
    
    
//    SDWindow* win = [SDWindow focusedWindow];
//    NSLog(@"%@", win);
//    
//    ctx[@"win"] = win;
//    
//    x = [ctx evaluateScript:@"_.map(win.app().allWindows(), function(w) { return w.title(); });"];
//    NSLog(@"%@", [x toObject]);
}

- (IBAction) reloadConfig:(id)sender {
    
}

- (IBAction) showAboutPanel:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp orderFrontStandardAboutPanel:sender];
}

- (IBAction) toggleOpenAtLogin:(NSMenuItem*)sender {
    [SDOpenAtLogin setOpensAtLogin:[sender state] == NSOffState];
}

- (void) menuNeedsUpdate:(NSMenu *)menu {
    [[menu itemWithTitle:@"Open at Login"] setState:([SDOpenAtLogin opensAtLogin] ? NSOnState : NSOffState)];
}

@end
