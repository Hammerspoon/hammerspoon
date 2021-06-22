#import "HSuicore.h"

#pragma mark - HSapplication implementation

@implementation HSapplication

#pragma mark - Class methods
+(HSapplication *)frontmostApplicationWithState:(lua_State *)L {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    HSapplication *frontmostApp = nil;

    NSRunningApplication *runningApp = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (runningApp) {
        frontmostApp = [HSapplication applicationForNSRunningApplication:runningApp withState:L];
        if (!frontmostApp) {
            [skin logError:[NSString stringWithFormat:@"HSapplication::frontmostApplication failed for app: %@", runningApp.localizedName]];
        }
    } else {
        [skin logError:@"Unable to fetch frontmost application"];
    }
    return frontmostApp;
}

+(HSapplication *)applicationForNSRunningApplication:(NSRunningApplication *)app withState:(lua_State *)L {
    return [[HSapplication alloc] initWithNSRunningApplication:app withState:L];
}

+(HSapplication *)applicationForPID:(pid_t)pid withState:(lua_State *)L {
    return [[HSapplication alloc] initWithPid:pid withState:L];
}

+(NSString *)nameForBundleID:(NSString *)bundleID {
    NSBundle *app = [NSBundle bundleWithPath:[HSapplication pathForBundleID:bundleID]];
    return [app objectForInfoDictionaryKey:(id)kCFBundleNameKey];
}

+(NSString *)pathForBundleID:(NSString *)bundleID {
    return [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:bundleID];
}

+(NSDictionary *)infoForBundleID:(NSString *)bundleID {
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    NSString *appPath = [ws absolutePathForAppBundleWithIdentifier:bundleID];
    return [HSapplication infoForBundlePath:appPath];
}

+(NSDictionary *)infoForBundlePath:(NSString *)bundlePath {
    NSDictionary *appInfo = nil;

    NSBundle *app = [NSBundle bundleWithPath:bundlePath];
    if (app) {
        appInfo = app.infoDictionary;
    }
    return appInfo;
}

+(NSArray<HSapplication *>*)runningApplicationsWithState:(lua_State *)L {
    NSMutableArray<HSapplication *> *apps = [[NSMutableArray alloc] init];

    for (NSRunningApplication* runningApp in [[NSWorkspace sharedWorkspace] runningApplications]) {
        HSapplication *app = [HSapplication applicationForNSRunningApplication:runningApp withState:L];
        if (app) {
            [apps addObject:app];
        }
    }

    return (NSArray *)[apps copy];
}

+(NSArray<HSapplication *>*)applicationsForBundleID:(NSString *)bundleID withState:(lua_State *)L {
    NSMutableArray<HSapplication *> *apps = [[NSMutableArray alloc] init];

    for (NSRunningApplication* runningApp in [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleID]) {
        HSapplication *app = [HSapplication applicationForNSRunningApplication:runningApp withState:L];
        if (app) {
            [apps addObject:app];
        }
    }

    return apps;
}

+(BOOL)launchByName:(NSString *)name {
    return [[NSWorkspace sharedWorkspace] launchApplication:name];
}

+(BOOL)launchByBundleID:(NSString *)bundleID {
    return [[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:bundleID
                                                                options:NSWorkspaceLaunchDefault
                                         additionalEventParamDescriptor:nil
                                                       launchIdentifier:NULL];
}

#pragma mark - Custom getter/setter methods
-(void)setHidden:(BOOL)shouldHide {
    AXUIElementSetAttributeValue(self.elementRef, (CFStringRef)NSAccessibilityHiddenAttribute, shouldHide ? kCFBooleanTrue : kCFBooleanFalse);
}

-(BOOL)isHidden {
    CFBooleanRef _isHidden;
    NSNumber* isHidden = @NO;
    AXError result = AXUIElementCopyAttributeValue(self.elementRef,
                                                   (CFStringRef)NSAccessibilityHiddenAttribute,
                                                   (CFTypeRef *)&_isHidden);
    if (result == kAXErrorSuccess) {
        isHidden = (__bridge_transfer NSNumber*)_isHidden;
    }
    return isHidden.boolValue;
}

#pragma mark - Instance initialisers
-(HSapplication *)initWithPid:(pid_t)pid withState:(lua_State *)L {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    NSRunningApplication *runningApp = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
    if (!runningApp) {
        [skin logError:[NSString stringWithFormat:@"Unable to fetch NSRunningApplication for pid: %d", pid]];
        return nil;
    }

    return [self initWithNSRunningApplication:runningApp withState:L];
}

-(HSapplication *)initWithNSRunningApplication:(NSRunningApplication *)app withState:(lua_State *)L {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    if (!app) {
        [skin logError:@"HSapplication::initWithNSRunningApplication called with invalid application"];
        return nil;
    }

    AXUIElementRef appRef = AXUIElementCreateApplication(app.processIdentifier);
    if (!appRef) {
        [skin logError:[NSString stringWithFormat:@"Unable to fetch AXUIElementRef for application: %@", app.localizedName]];
        return nil;
    }

    self = [super init];
    if (self) {
        _pid = app.processIdentifier;
        _elementRef = appRef; // no retain required because of AXUIElementCreateApplication above
        _runningApp = app;
        _uiElement = [[HSuielement alloc] initWithElementRef:_elementRef];
        _selfRefCount = 0;
    } else {
        CFRelease(appRef);
    }
    return self;
}

#pragma mark - Instance destructor
-(void)dealloc {
    if (_elementRef) CFRelease(_elementRef) ;
    _elementRef = NULL ;
}

#pragma mark - Instance methods
-(NSArray<HSwindow *>*)allWindows {
    NSMutableArray<HSwindow *> *allWindows = [[NSMutableArray alloc] init];
    CFArrayRef windows;
    AXError result = AXUIElementCopyAttributeValues(self.elementRef, kAXWindowsAttribute, 0, 100, &windows);
    if (result == kAXErrorSuccess) {
        CFIndex windowCount = CFArrayGetCount(windows);
        allWindows = [[NSMutableArray alloc] initWithCapacity:windowCount];
        for (NSInteger i = 0; i < windowCount; i++) {
            AXUIElementRef win = CFArrayGetValueAtIndex(windows, i);
            HSwindow *window = [[HSwindow alloc] initWithAXUIElementRef:win];
            [allWindows addObject:window];
        }
        CFRelease(windows);
    }
    return allWindows;
}

-(HSwindow *)mainWindow {
    HSwindow *mainWindow = nil;
    CFTypeRef window;
    if (AXUIElementCopyAttributeValue(self.elementRef, kAXMainWindowAttribute, &window) == kAXErrorSuccess) {
        mainWindow = [[HSwindow alloc] initWithAXUIElementRef:window];
        CFRelease(window);
    }
    return mainWindow;
}

-(HSwindow *)focusedWindow {
    HSwindow *focusedWindow = nil;
    CFTypeRef window;
    if (AXUIElementCopyAttributeValue(self.elementRef, kAXFocusedWindowAttribute, &window) == kAXErrorSuccess) {
        focusedWindow = [[HSwindow alloc] initWithAXUIElementRef:window];
        CFRelease(window);
    }
    return focusedWindow;
}

-(BOOL)activate:(BOOL)allWindows {
    return [self.runningApp activateWithOptions:NSApplicationActivateIgnoringOtherApps | (allWindows ? NSApplicationActivateAllWindows : 0)];
}

-(BOOL)isResponsive {
    // Define some private API we need
    typedef int CGSConnectionID;
    CG_EXTERN CGSConnectionID CGSMainConnectionID(void);
    bool CGSEventIsAppUnresponsive(CGSConnectionID cid, const ProcessSerialNumber *psn);
    // End of private API definitions

    ProcessSerialNumber psn;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    GetProcessForPID(self.pid, &psn);
#pragma clang diagnostic pop

    CGSConnectionID conn = CGSMainConnectionID();
    return !CGSEventIsAppUnresponsive(conn, &psn);
}

-(BOOL)isRunningWithState:(lua_State *)L {
    // FIXME: Figure out why we can't use NSRunningApplication.terminated here - it always seems to say NO
    //BOOL isTerminated = self.runningApp.terminated;
    HSapplication *test = [HSapplication applicationForPID:self.runningApp.processIdentifier withState:(lua_State *)L];
    return (test != nil);
}

-(BOOL)setFrontmost:(BOOL)allWindows {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    ProcessSerialNumber psn;
    GetProcessForPID(self.pid, &psn);
    return (SetFrontProcessWithOptions(&psn, allWindows ? 0 : kSetFrontProcessFrontWindowOnly) == noErr);
#pragma clang diagnostic pop
}

-(BOOL)isFrontmost {
    CFTypeRef _isFrontmost;
    NSNumber* isFrontmost = @NO;

    if (kAXErrorSuccess == AXUIElementCopyAttributeValue(self.elementRef,
                                                         (CFStringRef)NSAccessibilityFrontmostAttribute,
                                                         &_isFrontmost)) {
        isFrontmost = (__bridge_transfer NSNumber *)_isFrontmost;
//     } else {
//         [LuaSkin logError:[NSString stringWithFormat:@"Unable to fetch element attribute NSAccessibilityFrontmostAttribute for: %@", [self.runningApp localizedName]]];
    }

    //[LuaSkin logBreadcrumb:[NSString stringWithFormat:@"FRONTMOST: %@:%@:%@", self.title, isFrontmost, AXIsProcessTrusted() ? @"YES" : @"NO"]];

    return isFrontmost.boolValue;
}

-(NSString *)title {
    return self.runningApp.localizedName;
}

-(NSString *)bundleID {
    return self.runningApp.bundleIdentifier;
}

-(NSString *)path {
    return [NSBundle bundleWithURL:self.runningApp.bundleURL].bundlePath;
}

-(void)kill {
    [self.runningApp terminate];
}

-(void)kill9 {
    [self.runningApp forceTerminate];
}

-(int)kind {
    int kind = 1;
    switch (self.runningApp.activationPolicy) {
        case NSApplicationActivationPolicyAccessory:
            kind = 0;
            break;
        case NSApplicationActivationPolicyProhibited:
            kind = -1;
            break;
        default: break;
    }
    return kind;
}

@end

#pragma mark - HSuielement implementation

@implementation HSuielement

#pragma mark - Class methods
+(HSuielement *)focusedElement {
    HSuielement *focused = nil;
    AXUIElementRef focusedElement;
    AXUIElementRef systemWide = AXUIElementCreateSystemWide();

    AXError error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement);
    CFRelease(systemWide);

    if (error == kAXErrorSuccess) {
        focused = [[HSuielement alloc] initWithElementRef:focusedElement];
        CFRelease(focusedElement) ;
    }

    return focused;
}

#pragma mark - Instance initialiser
-(HSuielement *)initWithElementRef:(AXUIElementRef)elementRef {
    self = [super init];
    if (self) {
        _elementRef = CFRetain(elementRef);
        _selfRefCount = 0;
    }
    return self;
}

#pragma mark - Instance destructor
-(void)dealloc {
    if (_elementRef) CFRelease(_elementRef) ;
    _elementRef = NULL ;
}

#pragma mark - Instance methods
-(id)newWatcherAtIndex:(int)callbackRefIndex withUserdataAtIndex:(int)userDataRefIndex withLuaState:(lua_State *)L {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    int callbackRef = [skin luaRef:LUA_REGISTRYINDEX atIndex:callbackRefIndex];

    int userDataRef = LUA_REFNIL;
    if (lua_type(L, userDataRefIndex) != LUA_TNONE) {
        userDataRef = [skin luaRef:LUA_REGISTRYINDEX atIndex:userDataRefIndex];
    }

    HSuielementWatcher *watcher = [[HSuielementWatcher alloc] initWithElement:self
                                                                  callbackRef:(int)callbackRef
                                                                  userdataRef:(int)userDataRef];
    watcher.lsCanary = [skin createGCCanary];
    return watcher;
}

-(id)getElementProperty:(NSString *)property withDefaultValue:(id)defaultValue {
    CFTypeRef value;
    if (AXUIElementCopyAttributeValue(self.elementRef, (__bridge CFStringRef)property, &value) == kAXErrorSuccess) {
        return CFBridgingRelease(value);
    }
    return defaultValue;
}

-(BOOL)isApplication {
    return [self.role isEqualToString:(__bridge NSString *)kAXApplicationRole];
}

-(BOOL)isWindow {
    return [self isWindow:self.role];
}

-(BOOL)isWindow:(NSString *)role {
    // Most windows have a role of kAXWindowRole, but some apps are weird (e.g. Emacs) so we also do a duck-typing test for an expected window attribute
    return ([role isEqualToString:(__bridge NSString *)kAXWindowRole] || [self getElementProperty:NSAccessibilityMinimizedAttribute withDefaultValue:nil]);
}

-(NSString *)getRole {
    return [self getElementProperty:NSAccessibilityRoleAttribute withDefaultValue:@""];
}

-(NSString *)getSelectedText {
    NSString *selectedText = nil;
    AXValueRef _selectedText = NULL;
    if (AXUIElementCopyAttributeValue(self.elementRef, kAXSelectedTextAttribute, (CFTypeRef *)&_selectedText) == kAXErrorSuccess) {
        selectedText = (__bridge_transfer NSString *)_selectedText;
    }
    return selectedText;
}

@end

#pragma mark - HSuielementWatcher implementation

#pragma mark - Helper functions

static void watcher_observer_callback(AXObserverRef observer __unused, AXUIElementRef element,
                                      CFStringRef notificationName, void* contextData) {
    HSuielementWatcher *watcher = (__bridge HSuielementWatcher *)contextData;
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    [skin checkGCCanary:watcher.lsCanary];
    _lua_stackguard_entry(skin.L);


    [skin pushLuaRef:watcher.refTable ref:watcher.handlerRef]; // Callback function

    HSuielement *elementObj = [[HSuielement alloc] initWithElementRef:element];
    id pushObj = elementObj;
    if (elementObj.isWindow) {
        pushObj = [[HSwindow alloc] initWithAXUIElementRef:element];
    } else if ([elementObj.role isEqualToString:(__bridge NSString *)kAXApplicationRole]) {
        pid_t pid;
        AXUIElementGetPid(element, &pid);
        pushObj = [[HSapplication alloc] initWithPid:pid withState:skin.L];
    } else {
        // This isn't a window or an application, so we'll send it as an hs.uielement object
        pushObj = elementObj;
    }

    [skin pushNSObject:pushObj]; // Parameter 1: element
    lua_pushstring(skin.L, CFStringGetCStringPtr(notificationName, kCFStringEncodingASCII)); // Parameter 2: event
    [skin pushLuaRef:watcher.refTable ref:watcher.watcherRef]; // Parameter 3: watcher
    if (watcher.userDataRef == LUA_NOREF || watcher.userDataRef == LUA_REFNIL) {
        lua_pushnil(skin.L);
    } else {
        [skin pushLuaRef:watcher.refTable ref:watcher.userDataRef]; // Parameter 4: userData
    }

    if (![skin protectedCallAndTraceback:4 nresults:0]) {
        const char *errorMsg = lua_tostring(skin.L, -1);
        [skin logError:[NSString stringWithUTF8String:errorMsg]];
        lua_pop(skin.L, 1); // remove error message
    }

    _lua_stackguard_exit(skin.L);
    return;
}

@implementation HSuielementWatcher

#pragma mark - Instance initialiser
// NOTE THAT THE LUA REF ARGUMENTS MUST BE ON LUA_REGISTRYINDEX AND NOT SOME OTHER REFTABLE
-(HSuielementWatcher *)initWithElement:(HSuielement *)element callbackRef:(int)callbackRef userdataRef:(int)userdataRef{
    self = [super init];
    if (self) {
        _refTable = LUA_REGISTRYINDEX;
        _elementRef = CFRetain(element.elementRef);
        _selfRefCount = 0;
        _handlerRef = callbackRef;
        _userDataRef = userdataRef;
        _watcherRef = LUA_NOREF;
        _running = NO;
        _watchDestroyed = NO;
        AXUIElementGetPid(_elementRef, &_pid);
    }
    return self;
}

#pragma mark - Instance destructor
-(void)dealloc {
    if (_elementRef) CFRelease(_elementRef) ;
    _elementRef = NULL ;
}

#pragma mark - Instance methods

-(void)start:(NSArray <NSString *>*)events withState:(lua_State *)L {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    if (self.running) {
        return;
    }

    // Create our observer
    AXObserverRef observer = NULL;
    AXError err = AXObserverCreate(self.pid, watcher_observer_callback, &observer);
    if (err != kAXErrorSuccess) {
        [skin logBreadcrumb:[NSString stringWithFormat:@"AXObserverCreate error: %d", (int)err]];
        return;
    }

    // Add specified events to the observer
    for (NSString *event in events) {
        AXObserverAddNotification(observer, self.elementRef, (__bridge CFStringRef)event, (__bridge void *)self);
    }

    self.observer = observer;
    self.running = YES;

    // Begin observing events
    CFRunLoopAddSource([[NSRunLoop currentRunLoop] getCFRunLoop],
                       AXObserverGetRunLoopSource(observer),
                       kCFRunLoopDefaultMode);
}

-(void)stop {
    if (!self.running) {
        return;
    }

    CFRunLoopRemoveSource([[NSRunLoop currentRunLoop] getCFRunLoop],
                          AXObserverGetRunLoopSource(self.observer),
                          kCFRunLoopDefaultMode);
    CFRelease(self.observer);
    self.running = NO;
}
@end

#pragma mark - HSwindow implementation

#pragma mark - Helper functions
static AXUIElementRef system_wide_element() {
    static AXUIElementRef element;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        element = AXUIElementCreateSystemWide();
    });
    return element;
}

static AXUIElementRef get_window_tabs(AXUIElementRef win) {
    AXUIElementRef tabs = NULL;

    CFArrayRef children = NULL;
    if (AXUIElementCopyAttributeValues(win, kAXChildrenAttribute, 0, 100, &children) != noErr) {
        goto cleanup;
    }
    CFIndex count = CFArrayGetCount(children);

    CFTypeRef typeRef;
    for (CFIndex i = 0; i < count; ++i) {
        AXUIElementRef child = CFArrayGetValueAtIndex(children, i);
        if(AXUIElementCopyAttributeValue(child, kAXRoleAttribute, &typeRef) != noErr) goto cleanup;
        CFStringRef role = (CFStringRef)typeRef;
        BOOL correctRole = kCFCompareEqualTo == CFStringCompare(role, kAXTabGroupRole, 0);
        CFRelease(role);
        if (correctRole) {
            tabs = child;
            CFRetain(tabs);
            break;
        }
    }

    // Safari 14 puts them into an AXGroup, not an AXTabsGroup
    if (tabs == NULL) {
        for (CFIndex i = 0; i < count; ++i) {
            AXUIElementRef child = CFArrayGetValueAtIndex(children, i);
            if(AXUIElementCopyAttributeValue(child, kAXRoleAttribute, &typeRef) != noErr) goto cleanup;
            CFStringRef role = (CFStringRef)typeRef;
            BOOL correctRole = kCFCompareEqualTo == CFStringCompare(role, kAXGroupRole, 0);
            CFRelease(role);
            if (correctRole) {
                CFArrayRef attributeNames = NULL ;
                if (AXUIElementCopyAttributeNames(child, &attributeNames) != noErr) goto cleanup ;
                if (CFArrayContainsValue(attributeNames, CFRangeMake(0, CFArrayGetCount(attributeNames)), kAXTabsAttribute)) {
                    tabs = child;
                    CFRetain(tabs);
                    CFRelease(attributeNames) ;
                    break;
                }
                CFRelease(attributeNames) ;
            }
        }
    }

cleanup:
    if (children) CFRelease(children);

    return tabs;
}

@implementation HSwindow

#pragma mark - Class methods
+(NSArray<NSNumber *>*)orderedWindowIDs {
    NSMutableArray *windowIDs = [[NSMutableArray alloc] init];
    CFArrayRef wins = CGWindowListCreate(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);

    if (wins) {
        windowIDs = [[NSMutableArray alloc] initWithCapacity:CFArrayGetCount(wins)];
        for (int i = 0; i < CFArrayGetCount(wins); i++) {
            int winid = (int)CFArrayGetValueAtIndex(wins, i);
            [windowIDs addObject:[NSNumber numberWithInt:winid]];
        }
        CFRelease(wins);
    } else {
        [LuaSkin logBreadcrumb:@"hs.window._orderedwinids CGWindowListCreate returned NULL"] ;
    }
    return windowIDs;
}

+(NSImage *)snapshotForID:(int)windowID keepTransparency:(BOOL)keepTransparency {
    NSImage *image = nil;
    CGWindowImageOption makeOpaque = keepTransparency ? kCGWindowImageDefault : kCGWindowImageShouldBeOpaque;
    CGRect windowRect = CGRectNull;
    CFArrayRef targetWindow = CFArrayCreate(NULL, (const void **)(&windowID), 1, NULL);
    CGImageRef windowImage = CGWindowListCreateImageFromArray(windowRect,
                                                              targetWindow,
                                                              kCGWindowImageBoundsIgnoreFraming | makeOpaque);
    CFRelease(targetWindow);
    if (windowImage) {
        image = [[NSImage alloc] initWithCGImage:windowImage size:windowRect.size];
        CFRelease(windowImage);
    }
    return image;
}

+(HSwindow *)focusedWindow {
    HSwindow *window = nil;
    CFTypeRef app;
    AXUIElementCopyAttributeValue(system_wide_element(), kAXFocusedApplicationAttribute, &app);

    if (app) {
        CFTypeRef win;
        AXError result = AXUIElementCopyAttributeValue(app, (CFStringRef)NSAccessibilityFocusedWindowAttribute, &win);

        CFRelease(app);

        if (result == kAXErrorSuccess) {
            window = [[HSwindow alloc] initWithAXUIElementRef:win];
            CFRelease(win);
        }
    }
    return window;

}

#pragma mark - Initialiser
-(HSwindow *)initWithAXUIElementRef:(AXUIElementRef)winRef {
    self = [super init];
    if (self) {
        CFRetain(winRef);
        _elementRef = winRef; // retained above
        _selfRefCount = 0;

        pid_t pid;
        if (AXUIElementGetPid(winRef, &pid) == kAXErrorSuccess) {
            _pid = pid;
        }

        CGWindowID winID;
        AXError err = _AXUIElementGetWindow(winRef, &winID);
        if (!err) {
            _winID = winID;
        }

        _uiElement = [[HSuielement alloc] initWithElementRef:_elementRef];
    }
    return self;
}

#pragma mark - Destructor
-(void)dealloc {
    if (_elementRef) CFRelease(_elementRef) ;
    _elementRef = NULL ;
}

#pragma mark - Instance methods
-(id)getWindowProperty:(NSString *)property withDefaultValue:(id)defaultValue {
    CFTypeRef value;
    if (AXUIElementCopyAttributeValue(self.elementRef, (__bridge CFStringRef)property, &value) == kAXErrorSuccess) {
        return CFBridgingRelease(value);
    }
    return defaultValue;
}

-(BOOL)setWindowProperty:(NSString *)property withValue:(id)value {
    BOOL result = NO;
    if ([value isKindOfClass:NSNumber.class]) {
        result = (AXUIElementSetAttributeValue(self.elementRef, (__bridge CFStringRef)property, (__bridge CFTypeRef)value) == kAXErrorSuccess);
    }
    return result;
}

-(NSString *)title {
    return [self getWindowProperty:NSAccessibilityTitleAttribute withDefaultValue:@""];
}

-(NSString *)subRole {
    return [self getWindowProperty:NSAccessibilitySubroleAttribute withDefaultValue:@""];
}

-(NSString *)role {
    return [self getWindowProperty:NSAccessibilityRoleAttribute withDefaultValue:@""];
}

-(BOOL)isStandard {
    return [self.subRole isEqualToString:(NSString *)kAXStandardWindowSubrole];
}

// FIXME: Can getTopLeft/setTopLeft be converted to use/augment getWindowProperty/setWindowProperty?
-(NSPoint)getTopLeft {
    CGPoint topLeft = CGPointZero;
    CFTypeRef positionStorage;
    if (AXUIElementCopyAttributeValue(self.elementRef, (CFStringRef)NSAccessibilityPositionAttribute, &positionStorage) == kAXErrorSuccess) {
        if (!AXValueGetValue(positionStorage, kAXValueCGPointType, (void *)&topLeft)) {
            topLeft = CGPointZero;
        }
        CFRelease(positionStorage);
    }
    return NSMakePoint(topLeft.x, topLeft.y);
}

-(void)setTopLeft:(NSPoint)topLeft {
    CFTypeRef positionStorage = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&topLeft));
    AXUIElementSetAttributeValue(self.elementRef, (CFStringRef)NSAccessibilityPositionAttribute, positionStorage);
    if (positionStorage) {
        CFRelease(positionStorage);
    }
}

-(NSSize)getSize {
    CGSize size = CGSizeZero;
    CFTypeRef sizeStorage;
    if (AXUIElementCopyAttributeValue(self.elementRef, (CFStringRef)NSAccessibilitySizeAttribute, &sizeStorage) == kAXErrorSuccess) {
        if (!AXValueGetValue(sizeStorage, kAXValueCGSizeType, (void *)&size)) {
            size = CGSizeZero;
        }
        CFRelease(sizeStorage);
    }
    return NSMakeSize(size.width, size.height);
}

-(void)setSize:(NSSize)size {
    CFTypeRef sizeStorage = (CFTypeRef)(AXValueCreate(kAXValueCGSizeType, (const void *)&size));
    AXUIElementSetAttributeValue(self.elementRef, (CFStringRef)NSAccessibilitySizeAttribute, sizeStorage);
    if (sizeStorage) {
        CFRelease(sizeStorage);
    }
}

-(BOOL)pushButton:(CFStringRef)buttonId {
    BOOL worked = NO;
    AXUIElementRef button = NULL;
    if (AXUIElementCopyAttributeValue(self.elementRef, buttonId, (CFTypeRef*)&button) == noErr) {
        if (AXUIElementPerformAction(button, kAXPressAction) == noErr) {
            worked = YES;
        }
        CFRelease(button);
    }
    return worked;
}

-(void)toggleZoom {
    [self pushButton:kAXZoomButtonAttribute];
}

-(NSRect)getZoomButtonRect {
    NSRect rect = NSZeroRect;
    AXUIElementRef button = nil;
    CFTypeRef pointRef, sizeRef;
    CGPoint point;
    CGSize size;

    if (AXUIElementCopyAttributeValue(self.elementRef, kAXZoomButtonAttribute, (CFTypeRef*)&button) == noErr) {
        if ((AXUIElementCopyAttributeValue(button, kAXPositionAttribute, &pointRef) == noErr) && (AXUIElementCopyAttributeValue(button, kAXSizeAttribute, &sizeRef) == noErr)) {
                if (AXValueGetValue(pointRef, kAXValueCGPointType, &point) && AXValueGetValue(sizeRef, kAXValueCGSizeType, &size)) {
                    rect = NSMakeRect(point.x, point.y, size.width, size.height);
                }
        }
        CFRelease(button);
    }
    return rect;
}

-(BOOL)close {
    return [self pushButton:kAXCloseButtonAttribute];
}

-(int)getTabCount {
    CFIndex count = 0;
    AXUIElementRef tabs = get_window_tabs(self.elementRef);
    if (tabs) {
        AXUIElementGetAttributeValueCount(tabs, kAXTabsAttribute, &count);
        CFRelease(tabs);
    }
    return (int)count;
}

-(BOOL)focusTab:(int)index {
    BOOL worked = NO;
    CFArrayRef children = NULL;
    AXUIElementRef tab = NULL;

    AXUIElementRef tabs = get_window_tabs(self.elementRef);
    if(tabs == NULL) goto cleanup;

    if(AXUIElementCopyAttributeValues(tabs, kAXTabsAttribute, 0, 100, &children) != noErr) goto cleanup;
    CFIndex count = CFArrayGetCount(children);

    CFIndex i = index;
    if(i > count || i <= 0) {
        i = count - 1;
    } else {
        i = i - 1 ; // adjust because lua style indexes start at 1
    }
    tab = CFArrayGetValueAtIndex(children, i);

    if (AXUIElementPerformAction(tab, kAXPressAction) != noErr) goto cleanup;

    worked = YES;
cleanup:
    if (tabs) CFRelease(tabs);
    if (children) CFRelease(children);

    return worked;
}

-(void)setFullscreen:(BOOL)fullscreen {
    AXUIElementSetAttributeValue(self.elementRef, CFSTR("AXFullScreen"), fullscreen ? kCFBooleanTrue : kCFBooleanFalse);
}

-(BOOL)isFullscreen {
    BOOL fullscreen = NO;
    CFBooleanRef _fullscreen = kCFBooleanFalse;
    if (AXUIElementCopyAttributeValue(self.elementRef, CFSTR("AXFullScreen"), (CFTypeRef*)&_fullscreen) == noErr) {
        fullscreen = CFBooleanGetValue(_fullscreen);
        CFRelease(_fullscreen);
    }
    return fullscreen;
}

-(BOOL)isMinimized {
    NSNumber *minimized = [self getWindowProperty:NSAccessibilityMinimizedAttribute withDefaultValue:@(NO)];
    return minimized.boolValue;
}

-(void)setMinimized:(BOOL)minimize {
    [self setWindowProperty:NSAccessibilityMinimizedAttribute withValue:@(minimize)];
}

-(void)becomeMain {
    [self setWindowProperty:NSAccessibilityMainAttribute withValue:@(YES)];
}

-(void)raise {
    AXUIElementPerformAction(self.elementRef, kAXRaiseAction);
}

-(NSImage *)snapshot:(BOOL)keepTransparency {
    NSImage *image = nil;
    CGWindowID windowID;
    if (_AXUIElementGetWindow(self.elementRef, &windowID) == kAXErrorSuccess) {
        image = [HSwindow snapshotForID:windowID keepTransparency:keepTransparency];
    }
    return image;
}
@end
