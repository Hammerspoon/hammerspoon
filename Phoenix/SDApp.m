//
//  SDAppProxy.m
//  Zephyros
//
//  Created by Steven on 4/21/13.
//  Copyright (c) 2013 Giant Robot Software. All rights reserved.
//

#import "SDApp.h"

#import "SDWindow.h"
//#import "SDUniversalAccessHelper.h"

//#import "SDAppStalker.h"

//#import "SDObserver.h"


@interface SDApp ()

@property AXUIElementRef app;
@property (readwrite) pid_t pid;

@property NSMutableArray* observers;

- (id) initWithElement:(AXUIElementRef)element;

@end


@implementation SDApp

+ (NSArray*) runningApps {
    NSMutableArray* apps = [NSMutableArray array];
    
    for (NSRunningApplication* runningApp in [[NSWorkspace sharedWorkspace] runningApplications]) {
        SDApp* app = [[SDApp alloc] initWithPID:[runningApp processIdentifier]];
        [apps addObject:app];
    }
    
    return apps;
}

- (id) initWithElement:(AXUIElementRef)element {
    pid_t pid;
    AXUIElementGetPid(element, &pid);
    return [self initWithPID:pid];
}

- (id) initWithRunningApp:(NSRunningApplication*)app {
    return [self initWithPID:[app processIdentifier]];
}

- (id) initWithPID:(pid_t)pid {
    if (self = [super init]) {
        self.observers = [NSMutableArray array];
        self.pid = pid;
        self.app = AXUIElementCreateApplication(pid);
    }
    return self;
}

- (void) dealloc {
    self.observers = nil; // this will make them un-observe
    
    if (self.app)
        CFRelease(self.app);
}

- (BOOL) isEqual:(SDApp*)object {
    return ([self isKindOfClass: [object class]] &&
            self.pid == object.pid);
}

- (NSUInteger) hash {
    return self.pid;
}

- (NSArray*) visibleWindows {
    return [[self allWindows] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SDWindow* win, NSDictionary *bindings) {
        return ![[win app] isHidden]
        && ![win isWindowMinimized]
        && [win isNormalWindow];
    }]];
}

- (NSArray*) allWindows {
    NSMutableArray* windows = [NSMutableArray array];
    
    CFArrayRef _windows;
    AXError result = AXUIElementCopyAttributeValues(self.app, kAXWindowsAttribute, 0, 100, &_windows);
    if (result == kAXErrorSuccess) {
        for (NSInteger i = 0; i < CFArrayGetCount(_windows); i++) {
            AXUIElementRef win = CFArrayGetValueAtIndex(_windows, i);
            
            SDWindow* window = [[SDWindow alloc] initWithElement:win];
            [windows addObject:window];
        }
        CFRelease(_windows);
    }
    
    return windows;
}

- (BOOL) isHidden {
    CFTypeRef _isHidden;
    NSNumber* isHidden = @NO;
    if (AXUIElementCopyAttributeValue(self.app, (CFStringRef)NSAccessibilityHiddenAttribute, (CFTypeRef *)&_isHidden) == kAXErrorSuccess) {
        isHidden = CFBridgingRelease(_isHidden);
    }
    return [isHidden boolValue];
}

- (void) show {
    [self setAppProperty:NSAccessibilityHiddenAttribute withValue:@NO];
}

- (void) hide {
    [self setAppProperty:NSAccessibilityHiddenAttribute withValue:@YES];
}

- (NSString*) title {
    return [[NSRunningApplication runningApplicationWithProcessIdentifier:self.pid] localizedName];
}

- (void) kill {
    [[NSRunningApplication runningApplicationWithProcessIdentifier:self.pid] terminate];
}

- (void) kill9 {
    [[NSRunningApplication runningApplicationWithProcessIdentifier:self.pid] forceTerminate];
}

- (void) sendJustOneNotification:(NSString*)name withThing:(id)thing {
    NSNotification* note = [NSNotification notificationWithName:name object:nil userInfo:@{@"thing": thing}];
    [[NSNotificationQueue defaultQueue] enqueueNotification:note postingStyle:NSPostNow];
}

- (id) getAppProperty:(NSString*)propType withDefaultValue:(id)defaultValue {
    CFTypeRef _someProperty;
    if (AXUIElementCopyAttributeValue(self.app, (__bridge CFStringRef)propType, &_someProperty) == kAXErrorSuccess)
        return CFBridgingRelease(_someProperty);
    
    return defaultValue;
}

- (BOOL) setAppProperty:(NSString*)propType withValue:(id)value {
    AXError result = AXUIElementSetAttributeValue(self.app, (__bridge CFStringRef)(propType), (__bridge CFTypeRef)(value));
    return result == kAXErrorSuccess;
}

@end
