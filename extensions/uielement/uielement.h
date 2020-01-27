#import <Foundation/Foundation.h>
//#import <LuaSkin/LuaSkin.h>
#import "../application/application.h"
#import "../window/window.h"

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
