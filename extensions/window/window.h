#ifndef Window_application_h
#define Window_application_h

#import <Foundation/Foundation.h>
#import <lua.h>

static void new_window(lua_State* L, AXUIElementRef win) {
    AXUIElementRef* winptr = lua_newuserdata(L, sizeof(AXUIElementRef));
    *winptr = win;
    
    luaL_getmetatable(L, "hs.window");
    lua_setmetatable(L, -2);
    
    lua_newtable(L);
    lua_setuservalue(L, -2);
}

@interface TransformAnimation : NSAnimation

@property NSPoint newTopLeft;
@property NSPoint oldTopLeft;
@property NSSize newSize;
@property NSSize oldSize;

@property AXUIElementRef window;

@end

@implementation TransformAnimation

- (void)setCurrentProgress:(NSAnimationProgress)progress {
	[super setCurrentProgress:progress];
	float value = self.currentValue;

	NSPoint thePoint = (NSPoint) {
		_oldTopLeft.x + value * (_newTopLeft.x - _oldTopLeft.x),
		_oldTopLeft.y + value * (_newTopLeft.y - _oldTopLeft.y)
	};

	NSSize theSize = (NSSize) {
		_oldSize.width + value * (_newSize.width - _oldSize.width),
		_oldSize.height + value * (_newSize.height - _oldSize.height)
	};

	CFTypeRef positionStorage = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&thePoint));
	CFTypeRef sizeStorage = (CFTypeRef)(AXValueCreate(kAXValueCGSizeType, (const void *)&theSize));

	AXUIElementSetAttributeValue(_window, (CFStringRef)NSAccessibilityPositionAttribute, positionStorage);
	AXUIElementSetAttributeValue(_window, (CFStringRef)NSAccessibilitySizeAttribute, sizeStorage);

	if (sizeStorage) CFRelease(sizeStorage);
	if (positionStorage) CFRelease(positionStorage);
}

@end


#endif
