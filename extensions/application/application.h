#import <Foundation/Foundation.h>
#import <LuaSkin/LuaSkin.h>
#import "../window/window.h"

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

// Initialiser
-(HSapplication *)initWithPid:(pid_t)pid;

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
