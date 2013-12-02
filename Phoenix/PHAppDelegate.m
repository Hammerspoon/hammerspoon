//
//  PHAppDelegate.m
//  Phoenix
//
//  Created by Steven on 11/30/13.
//  Copyright (c) 2013 Steven. All rights reserved.
//

#import "PHAppDelegate.h"

#import "SDUniversalAccessHelper.h"
#import "SDOpenAtLogin.h"

@implementation PHAppDelegate

- (void) setupStatusItem {
    NSImage* img = [NSImage imageNamed:@"statusitem"];
    [img setTemplate:YES];
    
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self.statusItem setHighlightMode:YES];
    [self.statusItem setImage:img];
    [self.statusItem setMenu:self.statusItemMenu];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    if ([SDUniversalAccessHelper complainIfNeeded])
        [NSApp terminate:self];
    
    [self setupStatusItem];
    
    self.configLoader = [[PHConfigLoader alloc] init];
    [self.configLoader reload];
}

- (IBAction) reloadConfig:(id)sender {
    [self.configLoader reload];
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
