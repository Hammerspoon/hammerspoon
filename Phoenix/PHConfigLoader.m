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

@implementation PHConfigLoader

- (void) reload {
    JSContext* ctx = [[JSContext alloc] initWithVirtualMachine:[[JSVirtualMachine alloc] init]];
    
    NSURL* _jsURL = [[NSBundle mainBundle] URLForResource:@"underscore-min" withExtension:@"js"];
    NSString* _js = [NSString stringWithContentsOfURL:_jsURL encoding:NSUTF8StringEncoding error:NULL];
    [ctx evaluateScript:_js];
    
    JSValue* api = [JSValue valueWithNewObjectInContext:ctx];
    ctx[@"api"] = api;
    
    api[@"log"] = ^(NSString* str) {
        NSLog(@"%@", str);
    };
    
    
    ctx[@"Window"] = [SDWindow self];
    
    NSString* filename = [@"~/.phoenix.js" stringByStandardizingPath];
    NSString* config = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:NULL];
    
    [ctx evaluateScript:config];
}






//- (PHHotKey*) withKey:(NSString*)key mods:(NSArray*)mods handler:(JSValue*)handler {
//    return [PHHotKey withKey:key mods:mods handler:^BOOL(PHHotKey* hotkey) {
//        return [[handler callWithArguments:@[hotkey]] toBool];
//    }];
//}

@end
