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
    
    
    
    
    JSContext* ctx = [[JSContext alloc] initWithVirtualMachine:[[JSVirtualMachine alloc] init]];
    
    NSURL* _jsURL = [[NSBundle mainBundle] URLForResource:@"underscore-min" withExtension:@"js"];
    NSString* _js = [NSString stringWithContentsOfURL:_jsURL encoding:NSUTF8StringEncoding error:NULL];
    [ctx evaluateScript:_js];
    
//    ctx[@"foo"] = [JSValue valueWithObject:[[Foo alloc] init] inContext:ctx];
    
    JSValue* x = [ctx evaluateScript:@"(function(){ return 7; });"];
    NSLog(@"%@", [x callWithArguments:@[]]);
    
}

@end
