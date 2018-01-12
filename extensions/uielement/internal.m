@import Cocoa ;
@import Carbon ;
@import LuaSkin ;
#import "uielement.h"
#import "../window/window.h"
#import "../application/application.h"

#define get_element(L, idx) *((AXUIElementRef*)lua_touserdata(L, idx))

static const char* USERDATA_TAG = "hs.uielement";
static int refTable = LUA_NOREF;
#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

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
    }

    return focused;
}

#pragma mark - Instance initialiser
-(HSuielement *)initWithElementRef:(AXUIElementRef)elementRef {
    self = [super init];
    if (self) {
        _elementRef = elementRef;
        _selfRefCount = 0;
    }
    return self;
}

#pragma mark - Instance destructor
-(void)dealloc {
    CFRelease(self.elementRef);
}

#pragma mark - Instance methods
-(id)newWatcher:(int)callbackRef withUserdata:(int)userDataRef {
    // FIXME: Implement this
    HSuielementWatcher *watcher = [[HSuielementWatcher alloc] initWithElement:self callbackRef:(int)callbackRef userdataRef:(int)userDataRef];
    return watcher;
}

-(id)getElementProperty:(NSString *)property withDefaultValue:(id)defaultValue {
    CFTypeRef value;
    if (AXUIElementCopyAttributeValue(self.elementRef, (__bridge CFStringRef)property, &value) == kAXErrorSuccess) {
        return CFBridgingRelease(value);
    }
    return defaultValue;
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

/// hs.uielement.focusedElement() -> element or nil
/// Function
/// Gets the currently focused UI element
///
/// Parameters:
///  * None
///
/// Returns:
///  * An `hs.uielement` object or nil if no object could be found
static int uielement_focusedElement(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TBREAK];
    HSuielement *element = [HSuielement focusedElement];
    [skin pushNSObject:element];
    return 1;
}

/// hs.uielement:isWindow() -> bool
/// Method
/// Returns whether the UI element represents a window.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if the UI element is a window, otherwise false
static int uielement_iswindow(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSuielement *element = [skin toNSObjectAtIndex:1];
    lua_pushboolean(L, element.isWindow);
    return 1;
}

/// hs.uielement:role() -> string
/// Method
/// Returns the role of the element.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the role of the UI element
static int uielement_role(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSuielement *element = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:element.role];
    return 1;
}

/// hs.uielement:selectedText() -> string or nil
/// Method
/// Returns the selected text in the element
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the selected text, or nil if none could be found
///
/// Notes:
///  * Many applications (e.g. Safari, Mail, Firefox) do not implement the necessary accessibility features for this to work in their web views
static int uielement_selectedText(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSuielement *element = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:element.selectedText];
    return 1;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSuielement(lua_State *L, id obj) {
    HSuielement *value = obj;
    value.selfRefCount++;
    void** valuePtr = lua_newuserdata(L, sizeof(HSuielement *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSuielementFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared];
    HSuielement *value;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSuielement, L, idx, USERDATA_TAG);
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                        lua_typename(L, lua_type(L, idx))]];
    }
    return value;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int uielement_eq(lua_State* L) {
    BOOL isEqual = NO;
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared];
        HSuielement *element1 = [skin toNSObjectAtIndex:1];
        HSuielement *element2 = [skin toNSObjectAtIndex:2];
        isEqual = CFEqual(element1.elementRef, element2.elementRef);
    }
    lua_pushboolean(L, isEqual);
    return 1;
}

// Clean up a bare uielement if it isn't needed anymore.
static int uielement_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSuielement *element = get_objectFromUserdata(__bridge_transfer HSuielement, L, 1, USERDATA_TAG);
    if (element) {
        element.selfRefCount--;
        if (element.selfRefCount == 0) {
            element = nil;
        }
    }

    // Remove the Metatable so future use of the variable in Lua won't think it's valid
    lua_pushnil(L);
    lua_setmetatable(L, 1);
    return 0;
}

static const luaL_Reg moduleLib[] = {
    {"focusedElement", uielement_focusedElement},

    {NULL, NULL}
};

static const luaL_Reg module_metaLib[] = {
    {NULL, NULL}
};

static const luaL_Reg userdata_metaLib[] = {
    {"role", uielement_role},
    {"isWindow", uielement_iswindow},
    {"selectedText", uielement_selectedText},
    {NULL, NULL}
};

int luaopen_hs_uielement_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibrary:moduleLib metaFunctions:module_metaLib];
    [skin registerObject:USERDATA_TAG objectFunctions:userdata_metaLib];
    [skin registerPushNSHelper:pushHSuielement         forClass:"HSuielement"];
    [skin registerLuaObjectHelper:toHSuielementFromLua forClass:"HSuielement"
                                            withUserdataMapping:USERDATA_TAG];

    return 1;
}
