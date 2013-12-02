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





#import <objc/runtime.h>


@implementation PHConfigLoader

- (void) reload {
    
    Class k =
    [PHAPI self];
    
    Protocol* p = objc_allocateProtocol("PHHotKeyJSExport1234");
    
    protocol_addProtocol(p, @protocol(JSExport));
    
    Method* methods = class_copyMethodList(k, NULL);
    
    for (Method* method = methods; *method; method++) {
        SEL name = method_getName(*method);
        const char* types = method_getTypeEncoding(*method);
        protocol_addMethodDescription(p, name, types, YES, YES);
    }
    
    free(methods);
    
    objc_registerProtocol(p);
    
    
    
    class_addProtocol(k, p);
    
    
    
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
