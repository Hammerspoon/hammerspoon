//
//  PHConfigLoader.m
//  Phoenix
//
//  Created by Steven on 12/2/13.
//  Copyright (c) 2013 Steven. All rights reserved.
//

#import "PHConfigLoader.h"

#import <JavaScriptCore/JavaScriptCore.h>
#import "PHAPI.h"

@implementation PHConfigLoader

- (void) reload {
    JSContext* ctx = [[JSContext alloc] initWithVirtualMachine:[[JSVirtualMachine alloc] init]];
    
    NSURL* _jsURL = [[NSBundle mainBundle] URLForResource:@"underscore-min" withExtension:@"js"];
    NSString* _js = [NSString stringWithContentsOfURL:_jsURL encoding:NSUTF8StringEncoding error:NULL];
    [ctx evaluateScript:_js];
    
    id x = [[PHAPI alloc] init];
    
    ctx[@"api"] = x;
    
    NSString* filename = [@"~/.phoenix.js" stringByStandardizingPath];
    NSString* config = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:NULL];
    
    [ctx evaluateScript:config];
}

@end
