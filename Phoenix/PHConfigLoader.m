//
//  PHConfigLoader.m
//  Phoenix
//
//  Created by Steven on 12/2/13.
//  Copyright (c) 2013 Steven. All rights reserved.
//

#import "PHConfigLoader.h"

#import <JavaScriptCore/JavaScriptCore.h>
#import "SDWindow.h"
#import "PHHotKey.h"


@interface PHConfigLoader ()

@property NSMutableArray* hotkeys;

@end


@implementation PHConfigLoader

- (void) reload {
    [self.hotkeys makeObjectsPerformSelector:@selector(disable)];
    self.hotkeys = [NSMutableArray array];
    
    JSContext* ctx = [[JSContext alloc] initWithVirtualMachine:[[JSVirtualMachine alloc] init]];
    
    NSURL* _jsURL = [[NSBundle mainBundle] URLForResource:@"underscore-min" withExtension:@"js"];
    NSString* _js = [NSString stringWithContentsOfURL:_jsURL encoding:NSUTF8StringEncoding error:NULL];
    [ctx evaluateScript:_js];
    
    JSValue* api = [JSValue valueWithNewObjectInContext:ctx];
    ctx[@"api"] = api;
    
    api[@"log"] = ^(NSString* str) {
        NSLog(@"%@", str);
    };
    
    api[@"reload"] = ^(NSString* str) {
        [self reload];
    };
    
    api[@"bind"] = ^(NSString* key, NSArray* mods, JSValue* handler) {
        PHHotKey* hotkey = [PHHotKey withKey:key mods:mods handler:^BOOL(PHHotKey* hotkey) {
            return [[handler callWithArguments:@[hotkey]] toBool];
        }];
        [self.hotkeys addObject:hotkey];
        [hotkey enable];
        return hotkey;
    };
    
    
    ctx[@"Window"] = [SDWindow self];
    
    NSString* filename = [@"~/.phoenix.js" stringByStandardizingPath];
    NSString* config = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:NULL];
    
    [ctx evaluateScript:config];
}

@end
