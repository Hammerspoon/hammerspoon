@import Foundation;
@import LuaSkin;

#pragma mark - HSapplication declaration

@interface HSapplication : NSObject
@property (nonatomic, readonly) pid_t pid;
@property (nonatomic, readonly) AXUIElementRef elementRef;
@property (nonatomic, readonly) NSRunningApplication *runningApp;
@property (nonatomic) int selfRefCount;
@property (nonatomic, getter=isHidden, setter=setHidden:) BOOL hidden;

// Simplest class methods that just return an application
+(HSapplication *)frontmostApplication;

// Class methods that return an application matching a criteria
+(HSapplication *)applicationForPID:(pid_t)pid;
+(HSapplication *)applicationForNSRunningApplication:(NSRunningApplication *)app;

// Class methods that return application metadata based on an argument
+(NSString *)nameForBundleID:(NSString *)bundleID;
+(NSString *)pathForBundleID:(NSString *)bundleID;
+(NSDictionary *)infoForBundleID:(NSString *)bundleID;
+(NSDictionary *)infoForBundlePath:(NSString *)bundlePath;

// Class methods that return arrays of applications
+(NSArray<HSapplication *>*)runningApplications;
+(NSArray<HSapplication *>*)applicationsForBundleID:(NSString *)bundleID;

// Class methods that launch applications
+(BOOL)launchByName:(NSString *)name;
+(BOOL)launchByBundleID:(NSString *)bundleID;

// Custom getter/setter methods
-(void)setHidden:(BOOL)shouldHide;
-(BOOL)isHidden;

// Initialisers
-(HSapplication *)initWithPid:(pid_t)pid;
-(HSapplication *)initWithNSRunningApplication:(NSRunningApplication *)app;

// Destructor
-(void)dealloc;

// Instance methods
-(NSArray<id>*)allWindows;
-(id)mainWindow;
-(id)focusedWindow;
-(BOOL)activate:(BOOL)allWindows;
-(BOOL)isResponsive;
-(BOOL)isRunning;
-(BOOL)setFrontmost:(BOOL)allWindows;
-(BOOL)isFrontmost;
-(NSString *)title;
-(NSString *)bundleID;
-(NSString *)path;
-(void)kill;
-(void)kill9;
-(int)kind;

@end

#pragma mark - HSuielement declarations

@interface HSuielement : NSObject
@property (nonatomic, readonly) AXUIElementRef elementRef;
@property (nonatomic) int selfRefCount;
@property (nonatomic, readonly, getter=isWindow) BOOL isWindow;
@property (nonatomic, readonly, getter=getRole) NSString *role;
@property (nonatomic, readonly, getter=getSelectedText) NSString *selectedText;

// Class methods
+(HSuielement *)focusedElement;

// Instance initializer/destructor
-(HSuielement *)initWithElementRef:(AXUIElementRef)elementRef;
-(void)dealloc;

// Instance methods
-(id)newWatcher:(int)callbackRef withUserdata:(int)userDataRef;
-(id)getElementProperty:(NSString *)property withDefaultValue:(id)defaultValue;
-(BOOL)isWindow;
-(BOOL)isWindow:(NSString *)role;
-(NSString *)getRole;
-(NSString *)getSelectedText;
@end

@interface HSuielementWatcher : NSObject
@property (nonatomic) int selfRefCount;
@property (nonatomic) AXUIElementRef elementRef;
@property (nonatomic) int refTable;
@property (nonatomic) int handlerRef;
@property (nonatomic) int userDataRef;
@property (nonatomic) int watcherRef;
@property (nonatomic) AXObserverRef observer;
@property (nonatomic) pid_t pid;
@property (nonatomic) BOOL running;

-(HSuielementWatcher *)initWithElement:(HSuielement *)element callbackRef:(int)callbackRef userdataRef:(int)userdataRef;
-(void)dealloc;

-(void)start:(NSArray <NSString *>*)events;
-(void)stop;
@end

#pragma mark - HSwindow declaration

@interface HSwindow : NSObject
@property (nonatomic, readonly) pid_t pid;
@property (nonatomic, readonly) AXUIElementRef elementRef;
@property (nonatomic, readonly) CGWindowID winID;
@property (nonatomic) int selfRefCount;

@property (nonatomic, readonly, getter=title) NSString *title;
@property (nonatomic, readonly, getter=role) NSString *role;
@property (nonatomic, readonly, getter=subRole) NSString *subRole;
@property (nonatomic, readonly, getter=isStandard) BOOL isStandard;
@property (nonatomic, getter=getTopLeft, setter=setTopLeft:) NSPoint topLeft;
@property (nonatomic, getter=getSize, setter=setSize:) NSSize size;
@property (nonatomic, getter=isFullscreen, setter=setFullscreen:) BOOL fullscreen;
@property (nonatomic, getter=isMinimized, setter=setMinimized:) BOOL minimized;
@property (nonatomic, getter=getApplication) id application;
@property (nonatomic, readonly, getter=getZoomButtonRect) NSRect zoomButtonRect;
@property (nonatomic, readonly, getter=getTabCount) int tabCount;

// Class methods
+(NSArray<NSNumber *>*)orderedWindowIDs;
+(NSImage *)snapshotForID:(int)windowID keepTransparency:(BOOL)keepTransparency;
+(HSwindow *)focusedWindow;

// Initialiser
-(HSwindow *)initWithAXUIElementRef:(AXUIElementRef)winRef;

// Destructor
-(void)dealloc;

// Instance methods
-(NSString *)title;
-(NSString *)subRole;
-(NSString *)role;
-(BOOL)isStandard;
-(NSPoint)getTopLeft;
-(void)setTopLeft:(NSPoint)topLeft;
-(NSSize)getSize;
-(void)setSize:(NSSize)size;
-(BOOL)pushButton:(CFStringRef)buttonId;
-(void)toggleZoom;
-(NSRect)getZoomButtonRect;
-(BOOL)close;
-(BOOL)focusTab:(int)index;
-(int)getTabCount;
-(BOOL)isFullscreen;
-(void)setFullscreen:(BOOL)fullscreen;
-(BOOL)isMinimized;
-(void)setMinimized:(BOOL)minimize;
-(id)getApplication;
-(void)becomeMain;
-(void)raise;
-(NSImage *)snapshot:(BOOL)keepTransparency;
@end

extern AXError _AXUIElementGetWindow(AXUIElementRef, CGWindowID* out);
