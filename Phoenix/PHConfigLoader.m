//
//  PHConfigLoader.m
//  Phoenix
//
//  Created by Steven on 12/2/13.
//  Copyright (c) 2013 Steven. All rights reserved.
//

#import "PHConfigLoader.h"

#import <JavaScriptCore/JavaScriptCore.h>

#import "PHHotKey.h"
#import "PHAlerts.h"
#import "PHPathWatcher.h"

#import "PHMousePosition.h"

#import "PHWindow.h"
#import "PHApp.h"
#import "NSScreen+PHExtension.h"

@interface PHConfigLoader ()

@property NSMutableArray* hotkeys;
@property PHPathWatcher* watcher;

@end


static NSString* PHConfigPath = @"~/.phoenix.js";


@implementation PHConfigLoader

- (id) init {
    if (self = [super init]) {
        self.watcher = [PHPathWatcher watcherFor:PHConfigPath handler:^{
            [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(reload) object:nil];
            [self performSelector:@selector(reload) withObject:nil afterDelay:0.25];
        }];
    }
    return self;
}

- (void) reload {
    NSString* filename = [PHConfigPath stringByStandardizingPath];
    NSString* config = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:NULL];
    
    if (!config) {
        [[NSFileManager defaultManager] createFileAtPath:filename
                                                contents:[@"" dataUsingEncoding:NSUTF8StringEncoding]
                                              attributes:nil];
        [[PHAlerts sharedAlerts] show:@"I just created ~/.phoenix.js for you :)" duration:7.0];
        return;
    }
    
    [self.hotkeys makeObjectsPerformSelector:@selector(disable)];
    self.hotkeys = [NSMutableArray array];
    
    JSContext* ctx = [[JSContext alloc] initWithVirtualMachine:[[JSVirtualMachine alloc] init]];
    
    ctx.exceptionHandler = ^(JSContext* ctx, JSValue* val) {
        [[PHAlerts sharedAlerts] show:[NSString stringWithFormat:@"[js exception] %@", val] duration:3.0];
    };
    
    NSURL* _jsURL = [[NSBundle mainBundle] URLForResource:@"underscore-min" withExtension:@"js"];
    NSString* _js = [NSString stringWithContentsOfURL:_jsURL encoding:NSUTF8StringEncoding error:NULL];
    [ctx evaluateScript:_js];
    [self setupAPI:ctx];
    
    [ctx evaluateScript:config];
    [[PHAlerts sharedAlerts] show:@"Phoenix Config Loaded" duration:1.0];
}

- (void) setupAPI:(JSContext*)ctx {
    JSValue* api = [JSValue valueWithNewObjectInContext:ctx];
    ctx[@"api"] = api;
    
    api[@"reload"] = ^(NSString* str) {
        [self reload];
    };
    
    api[@"launch"] = ^(NSString* appName) {
        [[NSWorkspace sharedWorkspace] launchApplication:appName];
    };
    
    api[@"alert"] = ^(NSString* str, CGFloat duration) {
        if (isnan(duration))
            duration = 2.0;
        
        [[PHAlerts sharedAlerts] show:str duration:duration];
    };
    
    api[@"bind"] = ^(NSString* key, NSArray* mods, JSValue* handler) {
        PHHotKey* hotkey = [PHHotKey withKey:key mods:mods handler:^BOOL{
            return [[handler callWithArguments:@[]] toBool];
        }];
        [self.hotkeys addObject:hotkey];
        [hotkey enable];
        return hotkey;
    };
    
    ctx[@"Window"] = [PHWindow self];
    ctx[@"App"] = [PHApp self];
    ctx[@"Screen"] = [NSScreen self];
    ctx[@"MousePosition"] = [PHMousePosition self];
}

@end
