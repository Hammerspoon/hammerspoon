#import "common.h"

static LSRefTable refTable = LUA_NOREF ;

#pragma mark - Support Functions

int pushAXUIElement(lua_State *L, AXUIElementRef theElement) {
    AXUIElementRef* thePtr = lua_newuserdata(L, sizeof(AXUIElementRef)) ;
    *thePtr = CFRetain(theElement) ;
    luaL_getmetatable(L, USERDATA_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

const char *AXErrorAsString(AXError theError) {
    const char *ans ;
    switch(theError) {
        case kAXErrorSuccess:                           ans = "No error occurred" ; break ;
        case kAXErrorFailure:                           ans = "A system error occurred" ; break ;
        case kAXErrorIllegalArgument:                   ans = "Illegal argument" ; break ;
        case kAXErrorInvalidUIElement:                  ans = "AXUIElementRef is invalid" ; break ;
        case kAXErrorInvalidUIElementObserver:          ans = "Not a valid observer" ; break ;
        case kAXErrorCannotComplete:                    ans = "Messaging failed" ; break ;
        case kAXErrorAttributeUnsupported:              ans = "Attribute is not supported by target" ; break ;
        case kAXErrorActionUnsupported:                 ans = "Action is not supported by target" ; break ;
        case kAXErrorNotificationUnsupported:           ans = "Notification is not supported by target" ; break ;
        case kAXErrorNotImplemented:                    ans = "Function or method not implemented" ; break ;
        case kAXErrorNotificationAlreadyRegistered:     ans = "Notification has already been registered" ; break ;
        case kAXErrorNotificationNotRegistered:         ans = "Notification is not registered yet" ; break ;
        case kAXErrorAPIDisabled:                       ans = "The accessibility API is disabled" ; break ;
        case kAXErrorNoValue:                           ans = "Requested value does not exist" ; break ;
        case kAXErrorParameterizedAttributeUnsupported: ans = "Parameterized attribute is not supported" ; break ;
        case kAXErrorNotEnoughPrecision:                ans = "Not enough precision" ; break ;
        default:                                        ans = "Unrecognized error occured" ; break ;
    }
    return ans ;
}

static BOOL isApplicationOrSystem(AXUIElementRef theRef) {
    BOOL result = NO ;
    CFTypeRef value ;
    AXError errorState = AXUIElementCopyAttributeValue(theRef, (__bridge CFStringRef)@"AXRole", &value) ;
    if ((errorState == kAXErrorSuccess) &&
        (CFGetTypeID(value) == CFStringGetTypeID()) &&
        ([(__bridge NSString *)value isEqualToString:(__bridge NSString *)kAXApplicationRole] ||
         [(__bridge NSString *)value isEqualToString:(__bridge NSString *)kAXSystemWideRole])) {

        result = YES ;
    }
    if (value) CFRelease(value) ;
    return result ;
}

static int errorWrapper(lua_State *L, NSString *where, NSString *what, AXError err) {
    const char *axErrMsg = AXErrorAsString(err) ;

    if (what) {
        [LuaSkin logVerbose:[NSString stringWithFormat:@"%s:%@ AXError %d for %@: %s", USERDATA_TAG, where, err, what, axErrMsg]] ;
    } else {
        [LuaSkin logVerbose:[NSString stringWithFormat:@"%s:%@ AXError %d: %s", USERDATA_TAG, where, err, axErrMsg]] ;
    }

    lua_pushnil(L) ;
    lua_pushstring(L, axErrMsg) ;
    return 2 ;
}

#pragma mark - Module Functions

/// hs.axuielement.windowElement(windowObject) -> axuielementObject
/// Constructor
/// Returns the accessibility object for the window specified by the `hs.window` object.
///
/// Parameters:
///  * `windowObject` - the `hs.window` object for the window or a string or number which will be passed to `hs.window.find` to get an `hs.window` object.
///
/// Returns:
///  * an axuielementObject for the window specified
///
/// Notes:
///  * if `windowObject` is a string or number, only the first item found with `hs.window.find` will be used by this function to create an axuielementObject.
static int axuielement_getWindowElement(lua_State *L)      {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    // vararg here to mimic original behavior and allow constructs to use `hs.window(...)` as arg as this may
    // return more than one result
    [skin checkArgs:LS_TUSERDATA, "hs.window", LS_TBREAK | LS_TVARARG] ;
    NSObject *object = [skin toNSObjectAtIndex:1] ;
    AXUIElementRef ref = getElementRefPropertyFromClassObject(object) ;
    if (ref) {
        pushAXUIElement(L, ref) ;
        CFRelease(ref) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.axuielement.applicationElement(applicationObject) -> axuielementObject
/// Constructor
/// Returns the top-level accessibility object for the application specified by the `hs.application` object.
///
/// Parameters:
///  * `applicationObject` - the `hs.application` object for the Application or a string or number which will be passed to `hs.application.find` to get an `hs.application` object.
///
/// Returns:
///  * an axuielementObject for the application specified
///
/// Notes:
///  * if `applicationObject` is a string or number, only the first item found with `hs.application.find` will be used by this function to create an axuielementObject.
static int axuielement_getApplicationElement(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    // vararg here to mimic original behavior and allow constructs to use `hs.application(...)` as arg as this may
    // return more than one result
    [skin checkArgs:LS_TUSERDATA, "hs.application", LS_TBREAK | LS_TVARARG] ;
    NSObject *object = [skin toNSObjectAtIndex:1] ;
    AXUIElementRef ref = getElementRefPropertyFromClassObject(object) ;
    if (ref) {
        pushAXUIElement(L, ref) ;
        CFRelease(ref) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.axuielement.systemWideElement() -> axuielementObject
/// Constructor
/// Returns an accessibility object that provides access to system attributes.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the axuielementObject for the system attributes
static int axuielement_getSystemWideElement(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    AXUIElementRef value = AXUIElementCreateSystemWide() ;
    pushAXUIElement(L, value) ;
    CFRelease(value) ;
    return 1 ;
}

/// hs.axuielement.applicationElementForPID(pid) -> axuielementObject
/// Constructor
/// Returns the top-level accessibility object for the application with the specified process ID.
///
/// Parameters:
///  * `pid` - the process ID of the application.
///
/// Returns:
///  * an axuielementObject for the application specified, or nil if it cannot be determined
static int axuielement_getApplicationElementForPID(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER, LS_TBREAK] ;
    pid_t thePid = (pid_t)luaL_checkinteger(L, 1) ;
    AXUIElementRef value = AXUIElementCreateApplication(thePid) ;
    if (value && isApplicationOrSystem(value)) {
        pushAXUIElement(L, value) ;
    } else {
        lua_pushnil(L) ;
    }
    if (value) {
        CFRelease(value) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

/// hs.axuielement:copy() -> axuielementObject
/// Method
/// Return a duplicate userdata reference to the Accessibility object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a new userdata object representing a new reference to the Accessibility object.
static int axuielement_duplicateReference(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    pushAXUIElement(L, theRef) ;
    return 1 ;
}

/// hs.axuielement:attributeNames() -> table | nil, errString
/// Method
/// Returns a list of all the attributes supported by the specified accessibility object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an array of the names of all attributes supported by the axuielementObject or nil and an error string if an accessibility error occurred
///
/// Notes:
///  * Common attribute names can be found in the [hs.axuielement.attributes](#attributes) tables; however, this method will list only those names which are supported by this object, and is not limited to just those in the referenced table.
static int axuielement_getAttributeNames(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    CFArrayRef attributeNames ;
    AXError errorState = AXUIElementCopyAttributeNames(theRef, &attributeNames) ;
    int returnCount = 1 ;
    if (errorState == kAXErrorSuccess) {
        lua_newtable(L) ;
        for (id value in (__bridge NSArray *)attributeNames) {
            [skin pushNSObject:value] ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    } else {
        errorWrapper(L, @"attributeNames", nil, errorState) ;
        returnCount++ ;
    }
    if (attributeNames) CFRelease(attributeNames) ;
    return returnCount ;
}

/// hs.axuielement:actionNames() -> table | nil, errString
/// Method
/// Returns a list of all the actions the specified accessibility object can perform.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an array of the names of all actions supported by the axuielementObject or nil and an error string if an accessibility error occurred
///
/// Notes:
///  * Common action names can be found in the [hs.axuielement.actions](#actions) table; however, this method will list only those names which are supported by this object, and is not limited to just those in the referenced table.
static int axuielement_getActionNames(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    CFArrayRef attributeNames ;
    AXError errorState = AXUIElementCopyActionNames(theRef, &attributeNames) ;
    int returnCount = 1 ;
    if (errorState == kAXErrorSuccess) {
        lua_newtable(L) ;
        for (id value in (__bridge NSArray *)attributeNames) {
            [skin pushNSObject:value] ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    } else {
        errorWrapper(L, @"actionNames", nil, errorState) ;
        returnCount++ ;
    }
    if (attributeNames) CFRelease(attributeNames) ;
    return returnCount ;
}

/// hs.axuielement:actionDescription(action) -> string | nil, errString
/// Method
/// Returns a localized description of the specified accessibility object's action.
///
/// Parameters:
///  * `action` - the name of the action, as specified by [hs.axuielement:actionNames](#actionNames).
///
/// Returns:
///  * a string containing a description of the object's action, nil if no description is available, or nil and an error string if an accessibility error occurred
///
/// Notes:
///  * The action descriptions are provided by the target application; as such their accuracy and usefulness rely on the target application's developers.
static int axuielement_getActionDescription(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    NSString *action = [skin toNSObjectAtIndex:2] ;
    CFStringRef description ;
    AXError errorState = AXUIElementCopyActionDescription(theRef, (__bridge CFStringRef)action, &description) ;
    int returnCount = 1 ;
    if (errorState == kAXErrorSuccess) {
        [skin pushNSObject:(__bridge NSString *)description] ;
    } else if (errorState == kAXErrorNoValue) {
        lua_pushnil(L) ;
    } else {
        errorWrapper(L, @"actionDescription", action, errorState) ;
        returnCount++ ;
    }
    if (description) CFRelease(description) ;
    return returnCount ;
}

/// hs.axuielement:attributeValue(attribute) -> value | nil, errString
/// Method
/// Returns the value of an accessibility object's attribute.
///
/// Parameters:
///  * `attribute` - the name of the attribute, as specified by [hs.axuielement:attributeNames](#attributeNames).
///
/// Returns:
///  * the current value of the attribute, nil if the attribute has no value, or nil and an error string if an accessibility error occurred
static int axuielement_getAttributeValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    NSString *attribute = [skin toNSObjectAtIndex:2] ;
    CFTypeRef value ;
    AXError errorState = AXUIElementCopyAttributeValue(theRef, (__bridge CFStringRef)attribute, &value) ;
    int returnCount = 1 ;
    if (errorState == kAXErrorSuccess) {
        pushCFTypeToLua(L, value, refTable) ;
    } else if (errorState == kAXErrorNoValue) {
        lua_pushnil(L) ;
    } else {
        errorWrapper(L, @"attributeValue", attribute, errorState) ;
        returnCount++ ;
    }
    if (value) CFRelease(value) ;
    return returnCount ;
}

/// hs.axuielement:allAttributeValues([includeErrors]) -> table | nil, errString
/// Method
/// Returns a table containing key-value pairs for all attributes of the accessibility object.
///
/// Parameters:
///  * `includeErrors` - an optional boolean, default false, that specifies whether attribute names which generate an error when retrieved are included in the returned results.
///
/// Returns:
///  * a table with key-value pairs corresponding to the attributes of the accessibility object or nil and an error string if an accessibility error occurred
///
/// Notes:
///  * if `includeErrors` is not specified or is false, then attributes which exist for the element, but currently have no value assigned, will not appear in the table. This is because Lua treats a nil value for a table's key-value pair as an instruction to remove the key from the table, if it currently exists.
///  * To include attributes which exist but are currently unset, you need to specify `includeErrors` as true.
///    * attributes for which no value is currently assigned will be given a table value with the following key-value pairs:
///      * `_code` = -25212
///      * `error` = "Requested value does not exist"
static int axuielement_getAllAttributeValues(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    BOOL includeErrors = lua_gettop(L) == 2 ? (BOOL)lua_toboolean(L, 2) : NO ;
    CFArrayRef attributeNames ;
    AXError errorState = AXUIElementCopyAttributeNames(theRef, &attributeNames) ;
    int returnCount = 1 ;
    if (errorState == kAXErrorSuccess) {
        CFArrayRef values = nil ;
        errorState = AXUIElementCopyMultipleAttributeValues(theRef, attributeNames, 0, &values) ;
        if (errorState == kAXErrorSuccess) {
            lua_newtable(L) ;
            for(CFIndex idx = 0 ; idx < CFArrayGetCount(attributeNames) ; idx++) {
                CFTypeRef item = CFArrayGetValueAtIndex(values, idx) ;
                if ((CFGetTypeID(item) == AXValueGetTypeID()) && (AXValueGetType((AXValueRef)item) == kAXValueAXErrorType)) {
                    if (!includeErrors) continue ;
                }
                pushCFTypeToLua(L, item, refTable) ;
                lua_setfield(L, -2, [(__bridge NSString *)CFArrayGetValueAtIndex(attributeNames, idx) UTF8String]) ;
            }
        } else {
            errorWrapper(L, @"allAttributeValues", @"retrieving attribute values", errorState) ;
            returnCount++ ;
        }
        if (values) CFRelease(values) ;
    } else {
        errorWrapper(L, @"allAttributeValues", @"retrieving attribute names", errorState) ;
        returnCount++ ;
    }
    if (attributeNames) CFRelease(attributeNames) ;
    return returnCount ;
}

/// hs.axuielement:attributeValueCount(attribute) -> integer | nil, errString
/// Method
/// Returns the count of the array of an accessibility object's attribute value.
///
/// Parameters:
///  * `attribute` - the name of the attribute, as specified by [hs.axuielement:attributeNames](#attributeNames).
///
/// Returns:
///  * the number of items in the value for the attribute, if it is an array, or nil and an error string if an accessibility error occurred
static int axuielement_getAttributeValueCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    NSString *attribute = [skin toNSObjectAtIndex:2] ;
    CFIndex count ;
    AXError errorState = AXUIElementGetAttributeValueCount(theRef, (__bridge CFStringRef)attribute, &count) ;
    int returnCount = 1 ;
    if (errorState == kAXErrorSuccess) {
        lua_pushinteger(L, count) ;
    } else {
        errorWrapper(L, @"attributeValueCount", attribute, errorState) ;
        returnCount++ ;
    }
    return returnCount ;
}

/// hs.axuielement:parameterizedAttributeNames() -> table | nil, errString
/// Method
/// Returns a list of all the parameterized attributes supported by the specified accessibility object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an array of the names of all parameterized attributes supported by the axuielementObject or nil and an error string if an accessibility error occurred
static int axuielement_getParameterizedAttributeNames(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    CFArrayRef attributeNames ;
    AXError errorState = AXUIElementCopyParameterizedAttributeNames(theRef, &attributeNames) ;
    int returnCount = 1 ;
    if (errorState == kAXErrorSuccess) {
        lua_newtable(L) ;
        for (id value in (__bridge NSArray *)attributeNames) {
            [skin pushNSObject:value] ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    } else {
        errorWrapper(L, @"parameterizedAttributeNames", nil, errorState) ;
        returnCount++ ;
    }
    if (attributeNames) CFRelease(attributeNames) ;
    return returnCount ;
}

/// hs.axuielement:isAttributeSettable(attribute) -> boolean | nil, errString
/// Method
/// Returns whether the specified accessibility object's attribute can be modified.
///
/// Parameters:
///  * `attribute` - the name of the attribute, as specified by [hs.axuielement:attributeNames](#attributeNames).
///
/// Returns:
///  * a boolean value indicating whether or not the value of the parameter can be modified or nil and an error string if an accessibility error occurred
static int axuielement_isAttributeSettable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    NSString *attribute = [skin toNSObjectAtIndex:2] ;
    Boolean settable ;
    AXError errorState = AXUIElementIsAttributeSettable(theRef, (__bridge CFStringRef)attribute, &settable) ;
    int returnCount = 1 ;
    if (errorState == kAXErrorSuccess) {
        lua_pushboolean(L, settable) ;
    } else {
        errorWrapper(L, @"isAttributeSettable", attribute, errorState) ;
        returnCount++ ;
    }
    return returnCount ;
}

/// hs.axuielement:isValid() -> boolean | nil, errString
/// Method
/// Returns whether the specified accessibility object is still valid.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean value indicating whether or not the accessibility object is still valid or nil and an error string if any other accessibility error occurred
///
/// Notes:
///  * an accessibilityObject can become invalid for a variety of reasons, including but not limited to the element referred to no longer being available (e.g. an element referring to a window or one of its descendants that has been closed) or the application terminating.
static int axuielement_isValid(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    CFTypeRef value ;
    AXError errorState = AXUIElementCopyAttributeValue(theRef, (__bridge CFStringRef)@"AXRole", &value) ;
    int returnCount = 1 ;
    if (errorState == kAXErrorSuccess) {
        lua_pushboolean(L, YES) ;
    } else if (errorState == kAXErrorInvalidUIElement) {
        lua_pushboolean(L, NO) ;
    } else {
        errorWrapper(L, @"pid", nil, errorState) ;
        returnCount++ ;
    }
    if (value) CFRelease(value) ;
    return returnCount ;
}

/// hs.axuielement:pid() -> integer | nil, errString
/// Method
/// Returns the process ID associated with the specified accessibility object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the process ID for the application to which the accessibility object ultimately belongs or nil and an error string if an accessibility error occurred
static int axuielement_getPid(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    pid_t thePid ;
    AXError errorState = AXUIElementGetPid(theRef, &thePid) ;
    int returnCount = 1 ;
    if (errorState == kAXErrorSuccess) {
        lua_pushinteger(L, (lua_Integer)thePid) ;
    } else {
        errorWrapper(L, @"pid", nil, errorState) ;
        returnCount++ ;
    }
    return returnCount ;
}

/// hs.axuielement:performAction(action) -> axuielement | false | nil, errString
/// Method
/// Requests that the specified accessibility object perform the specified action.
///
/// Parameters:
///  * `action` - the name of the action, as specified by [hs.axuielement:actionNames](#actionNames).
///
/// Returns:
///  * if the requested action was accepted by the target, returns the axuielementObject; if the requested action was rejected, returns false; otherwise returns nil and an error string if an accessibility error occurred
///
/// Notes:
///  * The return value only suggests success or failure, but is not a guarantee.  The receiving application may have internal logic which prevents the action from occurring at this time for some reason, even though this method returns success (the axuielementObject).  Contrawise, the requested action may trigger a requirement for a response from the user and thus appear to time out, causing this method to return false or nil.
static int axuielement_performAction(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    NSString *action = [skin toNSObjectAtIndex:2] ;
    AXError errorState = AXUIElementPerformAction(theRef, (__bridge CFStringRef)action) ;
    int returnCount = 1 ;
    if (errorState == kAXErrorSuccess) {
        lua_pushvalue(L, 1) ;
    } else if (errorState == kAXErrorCannotComplete) {
        lua_pushboolean(L, NO) ;
    } else {
        errorWrapper(L, @"performAction", action, errorState) ;
        returnCount++ ;
    }
    return returnCount ;
}

/// hs.axuielement:elementAtPosition(x, y | pointTable) -> axuielementObject | nil, errString
/// Method
/// Returns the accessibility object at the specified position on the screen. The top-left corner of the primary screen is 0, 0.
///
/// Parameters:
///  * `x` - the x coordinate of the screen location to tes
///  * `y` - the y coordinate of the screen location to test
///  * `pointTable` - the x and y coordinates of the screen location to test, provided as a point-table, like the one returned by `hs.mouse.getAbsolutePosition`. A point-table is a table with key-value pairs for keys `x` and `y`.
///
/// Returns:
///  * an axuielementObject for the object at the specified coordinates, or nil and an error string if no object could be identified or an accessibility error occurred
///
/// Notes:
///  * This method can only be called on an axuielementObject that represents an application or the system-wide element (see [hs.axuielement.systemWideElement](#systemWideElement)).
///
///  * This function does hit-testing based on window z-order (that is, layering). If one window is on top of another window, the returned accessibility object comes from whichever window is topmost at the specified location.
///  * If this method is called on an axuielementObject representing an application, the search is restricted to the application.
///  * If this method is called on an axuielementObject representing the system-wide element, the search is not restricted to any particular application.  See [hs.axuielement.systemElementAtPosition](#systemElementAtPosition).
static int axuielement_getElementAtPosition(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TTABLE, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    int returnCount = 1 ;
    if (isApplicationOrSystem(theRef)) {
        float x, y ;
        if (lua_type(L, 2) == LUA_TTABLE && lua_gettop(L) == 2) {
            NSPoint thePoint = [skin tableToPointAtIndex:2] ;
            x = (float)thePoint.x ;
            y = (float)thePoint.y ;
        } else if (lua_gettop(L) == 3) {
            x = (float)lua_tonumber(L, 2) ;
            y = (float)lua_tonumber(L, 3) ;
        } else {
            return luaL_error(L, "point table or x and y as numbers expected") ;
        }
        AXUIElementRef value ;
        AXError errorState = AXUIElementCopyElementAtPosition(theRef, x, y, &value) ;
        if (errorState == kAXErrorSuccess) {
            pushAXUIElement(L, value) ;
        } else {
            errorWrapper(L, @"elementAtPosition", nil, errorState) ;
            returnCount++ ;
        }
        if (value) CFRelease(value) ;
    } else {
        return luaL_error(L, "must be application or systemWide element") ;
    }
    return returnCount ;
}

/// hs.axuielement:parameterizedAttributeValue(attribute, parameter) -> value | nil, errString
/// Method
/// Returns the value of an accessibility object's parameterized attribute.
///
/// Parameters:
///  * `attribute` - the name of the attribute, as specified by [hs.axuielement:parameterizedAttributeNames](#parameterizedAttributeNames).
///  * `parameter` - the parameter required by the paramaterized attribute.
///
/// Returns:
///  * the current value of the parameterized attribute, nil if the parameterized attribute has no value, or nil and an error string if an accessibility error occurred
///
/// Notes:
///  * The specific parameter required for a each parameterized attribute is different and is often application specific thus requiring some experimentation. Notes regarding identified parameter types and thoughts on some still being investigated will be provided in the Hammerspoon Wiki, hopefully shortly after this module becomes part of a Hammerspoon release.
static int axuielement_getParameterizedAttributeValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TANY, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    NSString *attribute = [skin toNSObjectAtIndex:2] ;
    CFTypeRef parameter = lua_toCFType(L, 3) ;
    CFTypeRef value ;
    AXError errorState = AXUIElementCopyParameterizedAttributeValue(theRef, (__bridge CFStringRef)attribute, parameter, &value) ;
    int returnCount = 1 ;
    if (errorState == kAXErrorSuccess) {
        pushCFTypeToLua(L, value, refTable) ;
    } else if (errorState == kAXErrorNoValue) {
        lua_pushnil(L) ;
    } else {
        errorWrapper(L, @"parameterizedAttributeValue", attribute, errorState) ;
        returnCount++ ;
    }
    if (value) CFRelease(value) ;
    if (parameter) CFRelease(parameter) ;
    return returnCount ;
}

/// hs.axuielement:setAttributeValue(attribute, value) -> axuielementObject  | nil, errString
/// Method
/// Sets the accessibility object's attribute to the specified value.
///
/// Parameters:
///  * `attribute` - the name of the attribute, as specified by [hs.axuielement:attributeNames](#attributeNames).
///  * `value`     - the value to assign to the attribute
///
/// Returns:
///  * the axuielementObject on success; nil and an error string if the attribute could not be set or an accessibility error occurred.
static int axuielement_setAttributeValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TANY, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    NSString *attribute = [skin toNSObjectAtIndex:2] ;
    CFTypeRef value = lua_toCFType(L, 3) ;
    AXError errorState = AXUIElementSetAttributeValue (theRef, (__bridge CFStringRef)attribute, value) ;
    int returnCount = 1 ;
    if (errorState == kAXErrorSuccess) {
        lua_pushvalue(L, 1) ;
    } else {
        errorWrapper(L, @"setAttributeValue", attribute, errorState) ;
        returnCount++ ;
    }
    if (value) CFRelease(value) ;
    return returnCount ;
}

/// hs.axuielement:asHSApplication() -> hs.application object | nil
/// Method
/// If the element referes to an application, return an `hs.application` object for the element.
///
/// Parameters:
///  * None
///
/// Returns:
///  * if the element refers to an application, return an `hs.application` object for the element ; otherwise return nil
///
/// Notes:
///  * An element is considered an application by this method if it has an AXRole of AXApplication and has a process identifier (pid).
static int axuielement_toHSApplication(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    CFTypeRef value ;
    AXError errorState = AXUIElementCopyAttributeValue(theRef, (__bridge CFStringRef)@"AXRole", &value) ;
    if ((errorState == kAXErrorSuccess) &&
        (CFGetTypeID(value) == CFStringGetTypeID()) &&
        ([(__bridge NSString *)value isEqualToString:(__bridge NSString *)kAXApplicationRole])) {
        pid_t thePid ;
        AXError errorState2 = AXUIElementGetPid(theRef, &thePid) ;
        if (errorState2 == kAXErrorSuccess) {
            new_application(L, thePid) ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        lua_pushnil(L) ;
    }
    if (value) CFRelease(value) ;
    return 1 ;
}

/// hs.axuielement:asHSWindow() -> hs.window object | nil
/// Method
/// If the element referes to a window, return an `hs.window` object for the element.
///
/// Parameters:
///  * None
///
/// Returns:
///  * if the element refers to a window, return an `hs.window` object for the element ; otherwise return nil
///
/// Notes:
///  * An element is considered a window by this method if it has an AXRole of AXWindow.
static int axuielement_toHSWindow(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    CFTypeRef value ;
    AXError errorState = AXUIElementCopyAttributeValue(theRef, (__bridge CFStringRef)@"AXRole", &value) ;
    if ((errorState == kAXErrorSuccess) &&
        (CFGetTypeID(value) == CFStringGetTypeID()) &&
        ([(__bridge NSString *)value isEqualToString:(__bridge NSString *)kAXWindowRole])) {
        new_window(L, theRef) ;
    } else {
        lua_pushnil(L) ;
    }
    if (value) CFRelease(value) ;

    return 1 ;
}

/// hs.axuielement:setTimeout(value) -> axuielementObject | nil, errString
/// Method
/// Sets the timeout value used accessibility queries performed from this element.
///
/// Parameters:
///  * `value` - the number of seconds for the new timeout value. Must be 0 or positive.
///
/// Returns:
///  * the axuielementObject or nil and an error string if an accessibility error occurred
///
/// Notes:
///  * To change the global timeout affecting all queries on elements which do not have a specific timeout set, use this method on the systemwide element (see [hs.axuielement.systemWideElement](#systemWideElement).
///  * Changing the timeout value for an axuielement object only changes the value for that specific element -- other axuieleement objects that may refer to the identical accessibiity item are not affected.
///
///  * Setting the value to 0.0 resets the timeout -- if applied to the `systemWideElement`, the global default will be reset to its default value; if applied to another axuielement object, the timeout will be reset to the current global value as applied to the systemWideElement.
static int axuielement_setTimeout(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    int returnCount = 1 ;
    float timeout = (float)lua_tonumber(L, 2) ;
    if (timeout < 0) timeout = 0 ;
    AXError errorState = AXUIElementSetMessagingTimeout(theRef, timeout) ;
    if (errorState == kAXErrorSuccess) {
        lua_pushvalue(L, 1) ;
    } else {
        errorWrapper(L, @"setTimeout", nil, errorState) ;
        returnCount++ ;
    }
    return returnCount ;
}

#pragma mark - Module Constants

/// hs.axuielement.attributes[]
/// Constant
/// A table of common accessibility object attribute names which may be used with [hs.axuielement:elementSearch](#elementSearch) or [hs.axuielement:matchesCriteria](#matchesCriteria) as keys in the match criteria argument.
///
/// Notes:
///  * This table is provided for reference only and is not intended to be comprehensive.
///  * You can view the contents of this table from the Hammerspoon console by typing in `hs.axuielement.attributes`
static int axuielement_pushAttributesTable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    lua_newtable(L) ;
    [skin pushNSObject:NSAccessibilityActivationPointAttribute] ;                     lua_setfield(L, -2, "activationPoint") ;
    [skin pushNSObject:(__bridge NSString *)kAXAllowedValuesAttribute] ;              lua_setfield(L, -2, "allowedValues") ;
    [skin pushNSObject:(__bridge NSString *)kAXAlternateUIVisibleAttribute] ;         lua_setfield(L, -2, "alternateUIVisible") ;
    [skin pushNSObject:(__bridge NSString *)kAXAMPMFieldAttribute] ;                  lua_setfield(L, -2, "AMPMField") ;
    [skin pushNSObject:(__bridge NSString *)kAXAttachmentTextAttribute] ;             lua_setfield(L, -2, "attachment") ;
    [skin pushNSObject:(__bridge NSString *)kAXAutocorrectedTextAttribute] ;          lua_setfield(L, -2, "autocorrected") ;
    [skin pushNSObject:(__bridge NSString *)kAXBackgroundColorTextAttribute] ;        lua_setfield(L, -2, "backgroundColor") ;
    [skin pushNSObject:(__bridge NSString *)kAXCancelButtonAttribute] ;               lua_setfield(L, -2, "cancelButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXChildrenAttribute] ;                   lua_setfield(L, -2, "children") ;
    [skin pushNSObject:(__bridge NSString *)kAXClearButtonAttribute] ;                lua_setfield(L, -2, "clearButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXCloseButtonAttribute] ;                lua_setfield(L, -2, "closeButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXColumnCountAttribute] ;                lua_setfield(L, -2, "columnCount") ;
    [skin pushNSObject:(__bridge NSString *)kAXColumnHeaderUIElementsAttribute] ;     lua_setfield(L, -2, "columnHeaderUIElements") ;
    [skin pushNSObject:(__bridge NSString *)kAXColumnIndexRangeAttribute] ;           lua_setfield(L, -2, "columnIndexRange") ;
    [skin pushNSObject:(__bridge NSString *)kAXColumnsAttribute] ;                    lua_setfield(L, -2, "columns") ;
    [skin pushNSObject:(__bridge NSString *)kAXColumnTitlesAttribute] ;               lua_setfield(L, -2, "columnTitles") ;
    [skin pushNSObject:NSAccessibilityContainsProtectedContentAttribute] ;            lua_setfield(L, -2, "containsProtectedContent") ;
    [skin pushNSObject:(__bridge NSString *)kAXContentsAttribute] ;                   lua_setfield(L, -2, "contents") ;
    [skin pushNSObject:(__bridge NSString *)kAXCriticalValueAttribute] ;              lua_setfield(L, -2, "criticalValue") ;
    [skin pushNSObject:(__bridge NSString *)kAXDayFieldAttribute] ;                   lua_setfield(L, -2, "dayField") ;
    [skin pushNSObject:(__bridge NSString *)kAXDecrementButtonAttribute] ;            lua_setfield(L, -2, "decrementButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXDefaultButtonAttribute] ;              lua_setfield(L, -2, "defaultButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXDescriptionAttribute] ;                lua_setfield(L, -2, "description") ;
    [skin pushNSObject:(__bridge NSString *)kAXDisclosedByRowAttribute] ;             lua_setfield(L, -2, "disclosedByRow") ;
    [skin pushNSObject:(__bridge NSString *)kAXDisclosedRowsAttribute] ;              lua_setfield(L, -2, "disclosedRows") ;
    [skin pushNSObject:(__bridge NSString *)kAXDisclosingAttribute] ;                 lua_setfield(L, -2, "disclosing") ;
    [skin pushNSObject:(__bridge NSString *)kAXDisclosureLevelAttribute] ;            lua_setfield(L, -2, "disclosureLevel") ;
    [skin pushNSObject:(__bridge NSString *)kAXDocumentAttribute] ;                   lua_setfield(L, -2, "document") ;
    [skin pushNSObject:(__bridge NSString *)kAXEditedAttribute] ;                     lua_setfield(L, -2, "edited") ;
    [skin pushNSObject:(__bridge NSString *)kAXElementBusyAttribute] ;                lua_setfield(L, -2, "elementBusy") ;
    [skin pushNSObject:(__bridge NSString *)kAXEnabledAttribute] ;                    lua_setfield(L, -2, "enabled") ;
    [skin pushNSObject:(__bridge NSString *)kAXExpandedAttribute] ;                   lua_setfield(L, -2, "expanded") ;
    [skin pushNSObject:(__bridge NSString *)kAXExtrasMenuBarAttribute] ;              lua_setfield(L, -2, "extrasMenuBar") ;
    [skin pushNSObject:(__bridge NSString *)kAXFilenameAttribute] ;                   lua_setfield(L, -2, "filename") ;
    [skin pushNSObject:(__bridge NSString *)kAXFocusedAttribute] ;                    lua_setfield(L, -2, "focused") ;
    [skin pushNSObject:(__bridge NSString *)kAXFocusedApplicationAttribute] ;         lua_setfield(L, -2, "focusedApplication") ;
    [skin pushNSObject:(__bridge NSString *)kAXFocusedUIElementAttribute] ;           lua_setfield(L, -2, "focusedUIElement") ;
    [skin pushNSObject:(__bridge NSString *)kAXFocusedWindowAttribute] ;              lua_setfield(L, -2, "focusedWindow") ;
    [skin pushNSObject:(__bridge NSString *)kAXFontTextAttribute] ;                   lua_setfield(L, -2, "font") ;
    [skin pushNSObject:(__bridge NSString *)kAXForegroundColorTextAttribute] ;        lua_setfield(L, -2, "foregroundColor") ;
    [skin pushNSObject:(__bridge NSString *)kAXFrontmostAttribute] ;                  lua_setfield(L, -2, "frontmost") ;
    [skin pushNSObject:(__bridge NSString *)kAXFullScreenButtonAttribute] ;           lua_setfield(L, -2, "fullScreenButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXGrowAreaAttribute] ;                   lua_setfield(L, -2, "growArea") ;
    [skin pushNSObject:(__bridge NSString *)kAXHandlesAttribute] ;                    lua_setfield(L, -2, "handles") ;
    [skin pushNSObject:(__bridge NSString *)kAXHeaderAttribute] ;                     lua_setfield(L, -2, "header") ;
    [skin pushNSObject:(__bridge NSString *)kAXHelpAttribute] ;                       lua_setfield(L, -2, "help") ;
    [skin pushNSObject:(__bridge NSString *)kAXHiddenAttribute] ;                     lua_setfield(L, -2, "hidden") ;
    [skin pushNSObject:(__bridge NSString *)kAXHorizontalScrollBarAttribute] ;        lua_setfield(L, -2, "horizontalScrollBar") ;
    [skin pushNSObject:(__bridge NSString *)kAXHorizontalUnitDescriptionAttribute] ;  lua_setfield(L, -2, "horizontalUnitDescription") ;
    [skin pushNSObject:(__bridge NSString *)kAXHorizontalUnitsAttribute] ;            lua_setfield(L, -2, "horizontalUnits") ;
    [skin pushNSObject:(__bridge NSString *)kAXHourFieldAttribute] ;                  lua_setfield(L, -2, "hourField") ;
    [skin pushNSObject:(__bridge NSString *)kAXIdentifierAttribute] ;                 lua_setfield(L, -2, "identifier") ;
    [skin pushNSObject:(__bridge NSString *)kAXIncrementButtonAttribute] ;            lua_setfield(L, -2, "incrementButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXIncrementorAttribute] ;                lua_setfield(L, -2, "incrementor") ;
    [skin pushNSObject:(__bridge NSString *)kAXIndexAttribute] ;                      lua_setfield(L, -2, "index") ;
    [skin pushNSObject:(__bridge NSString *)kAXInsertionPointLineNumberAttribute] ;   lua_setfield(L, -2, "insertionPointLineNumber") ;
    [skin pushNSObject:(__bridge NSString *)kAXIsApplicationRunningAttribute] ;       lua_setfield(L, -2, "isApplicationRunning") ;
    [skin pushNSObject:(__bridge NSString *)kAXIsEditableAttribute] ;                 lua_setfield(L, -2, "isEditable") ;
    [skin pushNSObject:(__bridge NSString *)kAXLabelUIElementsAttribute] ;            lua_setfield(L, -2, "labelUIElements") ;
    [skin pushNSObject:(__bridge NSString *)kAXLabelValueAttribute] ;                 lua_setfield(L, -2, "labelValue") ;
    [skin pushNSObject:(__bridge NSString *)kAXLinkTextAttribute] ;                   lua_setfield(L, -2, "link") ;
    [skin pushNSObject:(__bridge NSString *)kAXLinkedUIElementsAttribute] ;           lua_setfield(L, -2, "linkedUIElements") ;
    [skin pushNSObject:(__bridge NSString *)kAXListItemIndexTextAttribute] ;          lua_setfield(L, -2, "listItemIndex") ;
    [skin pushNSObject:(__bridge NSString *)kAXListItemLevelTextAttribute] ;          lua_setfield(L, -2, "listItemLevel") ;
    [skin pushNSObject:(__bridge NSString *)kAXListItemPrefixTextAttribute] ;         lua_setfield(L, -2, "listItemPrefix") ;
    [skin pushNSObject:(__bridge NSString *)kAXMainAttribute] ;                       lua_setfield(L, -2, "main") ;
    [skin pushNSObject:(__bridge NSString *)kAXMainWindowAttribute] ;                 lua_setfield(L, -2, "mainWindow") ;
    [skin pushNSObject:(__bridge NSString *)kAXMarkedMisspelledTextAttribute] ;       lua_setfield(L, -2, "markedMisspelled") ;
    [skin pushNSObject:NSAccessibilityMarkerGroupUIElementAttribute] ;                lua_setfield(L, -2, "markerGroupUIElement") ;
    [skin pushNSObject:(__bridge NSString *)kAXMarkerTypeAttribute] ;                 lua_setfield(L, -2, "markerType") ;
    [skin pushNSObject:(__bridge NSString *)kAXMarkerTypeDescriptionAttribute] ;      lua_setfield(L, -2, "markerTypeDescription") ;
    [skin pushNSObject:(__bridge NSString *)kAXMarkerUIElementsAttribute] ;           lua_setfield(L, -2, "markerUIElements") ;
    [skin pushNSObject:NSAccessibilityMarkerValuesAttribute] ;                        lua_setfield(L, -2, "markerValues") ;
    [skin pushNSObject:(__bridge NSString *)kAXMatteContentUIElementAttribute] ;      lua_setfield(L, -2, "matteContentUIElement") ;
    [skin pushNSObject:(__bridge NSString *)kAXMatteHoleAttribute] ;                  lua_setfield(L, -2, "matteHole") ;
    [skin pushNSObject:(__bridge NSString *)kAXMaxValueAttribute] ;                   lua_setfield(L, -2, "maxValue") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuBarAttribute] ;                    lua_setfield(L, -2, "menuBar") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuItemCmdCharAttribute] ;            lua_setfield(L, -2, "menuItemCmdChar") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuItemCmdGlyphAttribute] ;           lua_setfield(L, -2, "menuItemCmdGlyph") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuItemCmdModifiersAttribute] ;       lua_setfield(L, -2, "menuItemCmdModifiers") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuItemCmdVirtualKeyAttribute] ;      lua_setfield(L, -2, "menuItemCmdVirtualKey") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuItemMarkCharAttribute] ;           lua_setfield(L, -2, "menuItemMarkChar") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuItemPrimaryUIElementAttribute] ;   lua_setfield(L, -2, "menuItemPrimaryUIElement") ;
    [skin pushNSObject:(__bridge NSString *)kAXMinimizeButtonAttribute] ;             lua_setfield(L, -2, "minimizeButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXMinimizedAttribute] ;                  lua_setfield(L, -2, "minimized") ;
    [skin pushNSObject:(__bridge NSString *)kAXMinuteFieldAttribute] ;                lua_setfield(L, -2, "minuteField") ;
    [skin pushNSObject:(__bridge NSString *)kAXMinValueAttribute] ;                   lua_setfield(L, -2, "minValue") ;
    [skin pushNSObject:(__bridge NSString *)kAXMisspelledTextAttribute] ;             lua_setfield(L, -2, "misspelled") ;
    [skin pushNSObject:(__bridge NSString *)kAXModalAttribute] ;                      lua_setfield(L, -2, "modal") ;
    [skin pushNSObject:(__bridge NSString *)kAXMonthFieldAttribute] ;                 lua_setfield(L, -2, "monthField") ;
    [skin pushNSObject:(__bridge NSString *)kAXNaturalLanguageTextAttribute] ;        lua_setfield(L, -2, "naturalLanguage") ;
    [skin pushNSObject:(__bridge NSString *)kAXNextContentsAttribute] ;               lua_setfield(L, -2, "nextContents") ;
    [skin pushNSObject:(__bridge NSString *)kAXNumberOfCharactersAttribute] ;         lua_setfield(L, -2, "numberOfCharacters") ;
    [skin pushNSObject:(__bridge NSString *)kAXOrderedByRowAttribute] ;               lua_setfield(L, -2, "orderedByRow") ;
    [skin pushNSObject:(__bridge NSString *)kAXOrientationAttribute] ;                lua_setfield(L, -2, "orientation") ;
    [skin pushNSObject:(__bridge NSString *)kAXOverflowButtonAttribute] ;             lua_setfield(L, -2, "overflowButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXParentAttribute] ;                     lua_setfield(L, -2, "parent") ;
    [skin pushNSObject:(__bridge NSString *)kAXPlaceholderValueAttribute] ;           lua_setfield(L, -2, "placeholderValue") ;
    [skin pushNSObject:(__bridge NSString *)kAXPositionAttribute] ;                   lua_setfield(L, -2, "position") ;
    [skin pushNSObject:(__bridge NSString *)kAXPreviousContentsAttribute] ;           lua_setfield(L, -2, "previousContents") ;
    [skin pushNSObject:(__bridge NSString *)kAXProxyAttribute] ;                      lua_setfield(L, -2, "proxy") ;
    [skin pushNSObject:(__bridge NSString *)kAXReplacementStringTextAttribute] ;      lua_setfield(L, -2, "replacementString") ;
    [skin pushNSObject:NSAccessibilityRequiredAttribute] ;                            lua_setfield(L, -2, "required") ;
    [skin pushNSObject:(__bridge NSString *)kAXRoleAttribute] ;                       lua_setfield(L, -2, "role") ;
    [skin pushNSObject:(__bridge NSString *)kAXRoleDescriptionAttribute] ;            lua_setfield(L, -2, "roleDescription") ;
    [skin pushNSObject:(__bridge NSString *)kAXRowCountAttribute] ;                   lua_setfield(L, -2, "rowCount") ;
    [skin pushNSObject:(__bridge NSString *)kAXRowHeaderUIElementsAttribute] ;        lua_setfield(L, -2, "rowHeaderUIElements") ;
    [skin pushNSObject:(__bridge NSString *)kAXRowIndexRangeAttribute] ;              lua_setfield(L, -2, "rowIndexRange") ;
    [skin pushNSObject:(__bridge NSString *)kAXRowsAttribute] ;                       lua_setfield(L, -2, "rows") ;
    [skin pushNSObject:(__bridge NSString *)kAXSearchButtonAttribute] ;               lua_setfield(L, -2, "searchButton") ;
    [skin pushNSObject:NSAccessibilitySearchMenuAttribute] ;                          lua_setfield(L, -2, "searchMenu") ;
    [skin pushNSObject:(__bridge NSString *)kAXSecondFieldAttribute] ;                lua_setfield(L, -2, "secondField") ;
    [skin pushNSObject:(__bridge NSString *)kAXSelectedAttribute] ;                   lua_setfield(L, -2, "selected") ;
    [skin pushNSObject:(__bridge NSString *)kAXSelectedCellsAttribute] ;              lua_setfield(L, -2, "selectedCells") ;
    [skin pushNSObject:(__bridge NSString *)kAXSelectedChildrenAttribute] ;           lua_setfield(L, -2, "selectedChildren") ;
    [skin pushNSObject:(__bridge NSString *)kAXSelectedColumnsAttribute] ;            lua_setfield(L, -2, "selectedColumns") ;
    [skin pushNSObject:(__bridge NSString *)kAXSelectedRowsAttribute] ;               lua_setfield(L, -2, "selectedRows") ;
    [skin pushNSObject:(__bridge NSString *)kAXSelectedTextAttribute] ;               lua_setfield(L, -2, "selectedText") ;
    [skin pushNSObject:(__bridge NSString *)kAXSelectedTextRangeAttribute] ;          lua_setfield(L, -2, "selectedTextRange") ;
    [skin pushNSObject:(__bridge NSString *)kAXSelectedTextRangesAttribute] ;         lua_setfield(L, -2, "selectedTextRanges") ;
    [skin pushNSObject:(__bridge NSString *)kAXServesAsTitleForUIElementsAttribute] ; lua_setfield(L, -2, "servesAsTitleForUIElements") ;
    [skin pushNSObject:(__bridge NSString *)kAXShadowTextAttribute] ;                 lua_setfield(L, -2, "shadow") ;
    [skin pushNSObject:(__bridge NSString *)kAXSharedCharacterRangeAttribute] ;       lua_setfield(L, -2, "sharedCharacterRange") ;
    [skin pushNSObject:(__bridge NSString *)kAXSharedFocusElementsAttribute] ;        lua_setfield(L, -2, "sharedFocusElements") ;
    [skin pushNSObject:(__bridge NSString *)kAXSharedTextUIElementsAttribute] ;       lua_setfield(L, -2, "sharedTextUIElements") ;
    [skin pushNSObject:(__bridge NSString *)kAXShownMenuUIElementAttribute] ;         lua_setfield(L, -2, "shownMenuUIElement") ;
    [skin pushNSObject:(__bridge NSString *)kAXSizeAttribute] ;                       lua_setfield(L, -2, "size") ;
    [skin pushNSObject:(__bridge NSString *)kAXSortDirectionAttribute] ;              lua_setfield(L, -2, "sortDirection") ;
    [skin pushNSObject:(__bridge NSString *)kAXSplittersAttribute] ;                  lua_setfield(L, -2, "splitters") ;
    [skin pushNSObject:(__bridge NSString *)kAXStrikethroughTextAttribute] ;          lua_setfield(L, -2, "strikethrough") ;
    [skin pushNSObject:(__bridge NSString *)kAXStrikethroughColorTextAttribute] ;     lua_setfield(L, -2, "strikethroughColor") ;
    [skin pushNSObject:(__bridge NSString *)kAXSubroleAttribute] ;                    lua_setfield(L, -2, "subrole") ;
    [skin pushNSObject:(__bridge NSString *)kAXSuperscriptTextAttribute] ;            lua_setfield(L, -2, "superscript") ;
    [skin pushNSObject:(__bridge NSString *)kAXTabsAttribute] ;                       lua_setfield(L, -2, "tabs") ;
    [skin pushNSObject:(__bridge NSString *)kAXTextAttribute] ;                       lua_setfield(L, -2, "text") ;
    [skin pushNSObject:NSAccessibilityTextAlignmentAttribute];                        lua_setfield(L, -2, "textAlignment") ;
    [skin pushNSObject:(__bridge NSString *)kAXTitleAttribute] ;                      lua_setfield(L, -2, "title") ;
    [skin pushNSObject:(__bridge NSString *)kAXTitleUIElementAttribute] ;             lua_setfield(L, -2, "titleUIElement") ;
    [skin pushNSObject:(__bridge NSString *)kAXToolbarButtonAttribute] ;              lua_setfield(L, -2, "toolbarButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXTopLevelUIElementAttribute] ;          lua_setfield(L, -2, "topLevelUIElement") ;
    [skin pushNSObject:(__bridge NSString *)kAXUnderlineTextAttribute] ;              lua_setfield(L, -2, "underline") ;
    [skin pushNSObject:(__bridge NSString *)kAXUnderlineColorTextAttribute] ;         lua_setfield(L, -2, "underlineColor") ;
    [skin pushNSObject:(__bridge NSString *)kAXUnitDescriptionAttribute] ;            lua_setfield(L, -2, "unitDescription") ;
    [skin pushNSObject:(__bridge NSString *)kAXUnitsAttribute] ;                      lua_setfield(L, -2, "units") ;
    [skin pushNSObject:(__bridge NSString *)kAXURLAttribute] ;                        lua_setfield(L, -2, "URL") ;
    [skin pushNSObject:(__bridge NSString *)kAXValueAttribute] ;                      lua_setfield(L, -2, "value") ;
    [skin pushNSObject:(__bridge NSString *)kAXValueDescriptionAttribute] ;           lua_setfield(L, -2, "valueDescription") ;
    [skin pushNSObject:(__bridge NSString *)kAXValueIncrementAttribute] ;             lua_setfield(L, -2, "valueIncrement") ;
    [skin pushNSObject:(__bridge NSString *)kAXValueWrapsAttribute] ;                 lua_setfield(L, -2, "valueWraps") ;
    [skin pushNSObject:(__bridge NSString *)kAXVerticalScrollBarAttribute] ;          lua_setfield(L, -2, "verticalScrollBar") ;
    [skin pushNSObject:(__bridge NSString *)kAXVerticalUnitDescriptionAttribute] ;    lua_setfield(L, -2, "verticalUnitDescription") ;
    [skin pushNSObject:(__bridge NSString *)kAXVerticalUnitsAttribute] ;              lua_setfield(L, -2, "verticalUnits") ;
    [skin pushNSObject:(__bridge NSString *)kAXVisibleCellsAttribute] ;               lua_setfield(L, -2, "visibleCells") ;
    [skin pushNSObject:(__bridge NSString *)kAXVisibleCharacterRangeAttribute] ;      lua_setfield(L, -2, "visibleCharacterRange") ;
    [skin pushNSObject:(__bridge NSString *)kAXVisibleChildrenAttribute] ;            lua_setfield(L, -2, "visibleChildren") ;
    [skin pushNSObject:(__bridge NSString *)kAXVisibleColumnsAttribute] ;             lua_setfield(L, -2, "visibleColumns") ;
    [skin pushNSObject:(__bridge NSString *)kAXVisibleRowsAttribute] ;                lua_setfield(L, -2, "visibleRows") ;
    [skin pushNSObject:(__bridge NSString *)kAXVisibleTextAttribute] ;                lua_setfield(L, -2, "visibleText") ;
    [skin pushNSObject:(__bridge NSString *)kAXWarningValueAttribute] ;               lua_setfield(L, -2, "warningValue") ;
    [skin pushNSObject:(__bridge NSString *)kAXWindowAttribute] ;                     lua_setfield(L, -2, "window") ;
    [skin pushNSObject:(__bridge NSString *)kAXWindowsAttribute] ;                    lua_setfield(L, -2, "windows") ;
    [skin pushNSObject:(__bridge NSString *)kAXYearFieldAttribute] ;                  lua_setfield(L, -2, "yearField") ;
    [skin pushNSObject:(__bridge NSString *)kAXZoomButtonAttribute] ;                 lua_setfield(L, -2, "zoomButton") ;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
    [skin pushNSObject:NSAccessibilityAnnotationTextAttribute] ;                      lua_setfield(L, -2, "annotationText") ;
    [skin pushNSObject:NSAccessibilityCustomTextAttribute] ;                          lua_setfield(L, -2, "customText") ;
#pragma clang diagnostic pop

    return 1 ;
}

/// hs.axuielement.parameterizedAttributes[]
/// Constant
/// A table of common accessibility object parameterized attribute names, provided for reference.
///
/// Notes:
///  * this table is provided for reference only and is not intended to be comprehensive.
///  * you can view the contents of this table from the Hammerspoon console by typing in `hs.axuielement.parameterizedAttributes`
///
///  * Parameterized attributes are attributes that take an argument when querying the element. There is very little documentation available for most of these and application developers can implement their own for which we may never be able to get any documentation. This table contains parameterized attribute names that are defined within the Apple documentation and a few others that have been discovered.
///
///  * Documentation covering what has been discovered through experimentation about paramterized attributes is planned and should be added to the Hammerspoon wiki shortly after this module becomes part of a formal release.
static int axuielement_pushParamaterizedAttributesTable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kAXAttributedStringForRangeParameterizedAttribute] ;  lua_setfield(L, -2, "attributedStringForRange") ;
    [skin pushNSObject:(__bridge NSString *)kAXBoundsForRangeParameterizedAttribute] ;            lua_setfield(L, -2, "boundsForRange") ;
    [skin pushNSObject:(__bridge NSString *)kAXCellForColumnAndRowParameterizedAttribute] ;       lua_setfield(L, -2, "cellForColumnAndRow") ;
    [skin pushNSObject:(__bridge NSString *)kAXLayoutPointForScreenPointParameterizedAttribute] ; lua_setfield(L, -2, "layoutPointForScreenPoint") ;
    [skin pushNSObject:(__bridge NSString *)kAXLayoutSizeForScreenSizeParameterizedAttribute] ;   lua_setfield(L, -2, "layoutSizeForScreenSize") ;
    [skin pushNSObject:(__bridge NSString *)kAXLineForIndexParameterizedAttribute] ;              lua_setfield(L, -2, "lineForIndex") ;
    [skin pushNSObject:(__bridge NSString *)kAXRangeForIndexParameterizedAttribute] ;             lua_setfield(L, -2, "rangeForIndex") ;
    [skin pushNSObject:(__bridge NSString *)kAXRangeForLineParameterizedAttribute] ;              lua_setfield(L, -2, "rangeForLine") ;
    [skin pushNSObject:(__bridge NSString *)kAXRangeForPositionParameterizedAttribute] ;          lua_setfield(L, -2, "rangeForPosition") ;
    [skin pushNSObject:(__bridge NSString *)kAXRTFForRangeParameterizedAttribute] ;               lua_setfield(L, -2, "RTFForRange") ;
    [skin pushNSObject:(__bridge NSString *)kAXScreenPointForLayoutPointParameterizedAttribute] ; lua_setfield(L, -2, "screenPointForLayoutPoint") ;
    [skin pushNSObject:(__bridge NSString *)kAXScreenSizeForLayoutSizeParameterizedAttribute] ;   lua_setfield(L, -2, "screenSizeForLayoutSize") ;
    [skin pushNSObject:(__bridge NSString *)kAXStringForRangeParameterizedAttribute] ;            lua_setfield(L, -2, "stringForRange") ;
    [skin pushNSObject:(__bridge NSString *)kAXStyleRangeForIndexParameterizedAttribute] ;        lua_setfield(L, -2, "styleRangeForIndex") ;

// // FIXME: undecided if these should be included in release...
#if defined(HS_EXTERNAL_MODULE)
    [skin pushNSObject:NSAccessibilityAttributedValueForStringAttributeParameterizedAttribute] ;  lua_setfield(L, -2, "attributedValueForStringAttribute") ;
    [skin pushNSObject:NSAccessibilityFocusRingManipulationParameterizedAttribute] ;              lua_setfield(L, -2, "focusRingManipulation") ;
    [skin pushNSObject:NSAccessibilityIndexForChildUIElementParameterizedAttribute] ;             lua_setfield(L, -2, "indexForChildUIElement") ;
    [skin pushNSObject:NSAccessibilityLoadSearchResultParameterizedAttribute] ;                   lua_setfield(L, -2, "loadSearchResult") ;
    [skin pushNSObject:NSAccessibilityReplaceRangeWithTextParameterizedAttribute] ;               lua_setfield(L, -2, "replaceRangeWithText") ;
    [skin pushNSObject:NSAccessibilityResultsForSearchPredicateParameterizedAttribute] ;          lua_setfield(L, -2, "resultsForSearchPredicate") ;
    [skin pushNSObject:NSAccessibilityScrollToShowDescendantParameterizedAttributeAction] ;       lua_setfield(L, -2, "scrollToShowDescendant") ;
#endif
    return 1 ;
}

/// hs.axuielement.actions[]
/// Constant
/// A table of common accessibility object action names, provided for reference.
///
/// Notes:
///  * this table is provided for reference only and is not intended to be comprehensive.
///  * you can view the contents of this table from the Hammerspoon console by typing in `hs.axuielement.actions`
static int axuielement_pushActionsTable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kAXCancelAction] ;          lua_setfield(L, -2, "cancel") ;
    [skin pushNSObject:(__bridge NSString *)kAXConfirmAction] ;         lua_setfield(L, -2, "confirm") ;
    [skin pushNSObject:(__bridge NSString *)kAXDecrementAction] ;       lua_setfield(L, -2, "decrement") ;
    [skin pushNSObject:NSAccessibilityDeleteAction] ;                   lua_setfield(L, -2, "delete") ;
    [skin pushNSObject:(__bridge NSString *)kAXIncrementAction] ;       lua_setfield(L, -2, "increment") ;
    [skin pushNSObject:(__bridge NSString *)kAXPickAction] ;            lua_setfield(L, -2, "pick") ;
    [skin pushNSObject:(__bridge NSString *)kAXPressAction] ;           lua_setfield(L, -2, "press") ;
    [skin pushNSObject:(__bridge NSString *)kAXRaiseAction] ;           lua_setfield(L, -2, "raise") ;
    [skin pushNSObject:(__bridge NSString *)kAXShowAlternateUIAction] ; lua_setfield(L, -2, "showAlternateUI") ;
    [skin pushNSObject:(__bridge NSString *)kAXShowDefaultUIAction] ;   lua_setfield(L, -2, "showDefaultUI") ;
    [skin pushNSObject:(__bridge NSString *)kAXShowMenuAction] ;        lua_setfield(L, -2, "showMenu") ;
    return 1 ;
}

/// hs.axuielement.roles[]
/// Constant
/// A table of common accessibility object roles which may be used with [hs.axuielement:elementSearch](#elementSearch) or [hs.axuielement:matchesCriteria](#matchesCriteria) as attribute values for "AXRole" in the match criteria argument.
///
/// Notes:
///  * this table is provided for reference only and is not intended to be comprehensive.
///  * you can view the contents of this table from the Hammerspoon console by typing in `hs.axuielement.roles`
static int axuielement_pushRolesTable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kAXApplicationRole] ;        lua_setfield(L, -2, "application") ;
    [skin pushNSObject:(__bridge NSString *)kAXBrowserRole] ;            lua_setfield(L, -2, "browser") ;
    [skin pushNSObject:(__bridge NSString *)kAXBusyIndicatorRole] ;      lua_setfield(L, -2, "busyIndicator") ;
    [skin pushNSObject:(__bridge NSString *)kAXButtonRole] ;             lua_setfield(L, -2, "button") ;
    [skin pushNSObject:(__bridge NSString *)kAXCellRole] ;               lua_setfield(L, -2, "cell") ;
    [skin pushNSObject:(__bridge NSString *)kAXCheckBoxRole] ;           lua_setfield(L, -2, "checkBox") ;
    [skin pushNSObject:(__bridge NSString *)kAXColorWellRole] ;          lua_setfield(L, -2, "colorWell") ;
    [skin pushNSObject:(__bridge NSString *)kAXColumnRole] ;             lua_setfield(L, -2, "column") ;
    [skin pushNSObject:(__bridge NSString *)kAXComboBoxRole] ;           lua_setfield(L, -2, "comboBox") ;
    [skin pushNSObject:(__bridge NSString *)kAXDateFieldRole] ;          lua_setfield(L, -2, "dateField") ;
    [skin pushNSObject:(__bridge NSString *)kAXDisclosureTriangleRole] ; lua_setfield(L, -2, "disclosureTriangle") ;
    [skin pushNSObject:(__bridge NSString *)kAXDockItemRole] ;           lua_setfield(L, -2, "dockItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXDrawerRole] ;             lua_setfield(L, -2, "drawer") ;
    [skin pushNSObject:(__bridge NSString *)kAXGridRole] ;               lua_setfield(L, -2, "grid") ;
    [skin pushNSObject:(__bridge NSString *)kAXGroupRole] ;              lua_setfield(L, -2, "group") ;
    [skin pushNSObject:(__bridge NSString *)kAXGrowAreaRole] ;           lua_setfield(L, -2, "growArea") ;
    [skin pushNSObject:(__bridge NSString *)kAXHandleRole] ;             lua_setfield(L, -2, "handle") ;
    [skin pushNSObject:(__bridge NSString *)kAXHelpTagRole] ;            lua_setfield(L, -2, "helpTag") ;
    [skin pushNSObject:(__bridge NSString *)kAXImageRole] ;              lua_setfield(L, -2, "image") ;
    [skin pushNSObject:(__bridge NSString *)kAXIncrementorRole] ;        lua_setfield(L, -2, "incrementor") ;
    [skin pushNSObject:(__bridge NSString *)kAXLayoutAreaRole] ;         lua_setfield(L, -2, "layoutArea") ;
    [skin pushNSObject:(__bridge NSString *)kAXLayoutItemRole] ;         lua_setfield(L, -2, "layoutItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXLevelIndicatorRole] ;     lua_setfield(L, -2, "levelIndicator") ;
    [skin pushNSObject:(__bridge NSString *)kAXListRole] ;               lua_setfield(L, -2, "list") ;
    [skin pushNSObject:(__bridge NSString *)kAXMatteRole] ;              lua_setfield(L, -2, "matteRole") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuRole] ;               lua_setfield(L, -2, "menu") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuBarRole] ;            lua_setfield(L, -2, "menuBar") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuBarItemRole] ;        lua_setfield(L, -2, "menuBarItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuButtonRole] ;         lua_setfield(L, -2, "menuButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXMenuItemRole] ;           lua_setfield(L, -2, "menuItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXOutlineRole] ;            lua_setfield(L, -2, "outline") ;
    [skin pushNSObject:(__bridge NSString *)kAXPopoverRole] ;            lua_setfield(L, -2, "popover") ;
    [skin pushNSObject:(__bridge NSString *)kAXPopUpButtonRole] ;        lua_setfield(L, -2, "popUpButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXProgressIndicatorRole] ;  lua_setfield(L, -2, "progressIndicator") ;
    [skin pushNSObject:(__bridge NSString *)kAXRadioButtonRole] ;        lua_setfield(L, -2, "radioButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXRadioGroupRole] ;         lua_setfield(L, -2, "radioGroup") ;
    [skin pushNSObject:(__bridge NSString *)kAXRelevanceIndicatorRole] ; lua_setfield(L, -2, "relevanceIndicator") ;
    [skin pushNSObject:(__bridge NSString *)kAXRowRole] ;                lua_setfield(L, -2, "row") ;
    [skin pushNSObject:(__bridge NSString *)kAXRulerRole] ;              lua_setfield(L, -2, "ruler") ;
    [skin pushNSObject:(__bridge NSString *)kAXRulerMarkerRole] ;        lua_setfield(L, -2, "rulerMarker") ;
    [skin pushNSObject:(__bridge NSString *)kAXScrollAreaRole] ;         lua_setfield(L, -2, "scrollArea") ;
    [skin pushNSObject:(__bridge NSString *)kAXScrollBarRole] ;          lua_setfield(L, -2, "scrollBar") ;
    [skin pushNSObject:(__bridge NSString *)kAXSheetRole] ;              lua_setfield(L, -2, "sheet") ;
    [skin pushNSObject:(__bridge NSString *)kAXSliderRole] ;             lua_setfield(L, -2, "slider") ;
    [skin pushNSObject:(__bridge NSString *)kAXSplitGroupRole] ;         lua_setfield(L, -2, "splitGroup") ;
    [skin pushNSObject:(__bridge NSString *)kAXSplitterRole] ;           lua_setfield(L, -2, "splitter") ;
    [skin pushNSObject:(__bridge NSString *)kAXStaticTextRole] ;         lua_setfield(L, -2, "staticText") ;
    [skin pushNSObject:(__bridge NSString *)kAXSystemWideRole] ;         lua_setfield(L, -2, "systemWide") ;
    [skin pushNSObject:(__bridge NSString *)kAXTabGroupRole] ;           lua_setfield(L, -2, "tabGroup") ;
    [skin pushNSObject:(__bridge NSString *)kAXTableRole] ;              lua_setfield(L, -2, "table") ;
    [skin pushNSObject:(__bridge NSString *)kAXTextAreaRole] ;           lua_setfield(L, -2, "textArea") ;
    [skin pushNSObject:(__bridge NSString *)kAXTextFieldRole] ;          lua_setfield(L, -2, "textField") ;
    [skin pushNSObject:(__bridge NSString *)kAXTimeFieldRole] ;          lua_setfield(L, -2, "timeField") ;
    [skin pushNSObject:(__bridge NSString *)kAXToolbarRole] ;            lua_setfield(L, -2, "toolbar") ;
    [skin pushNSObject:(__bridge NSString *)kAXUnknownRole] ;            lua_setfield(L, -2, "unknown") ;
    [skin pushNSObject:(__bridge NSString *)kAXValueIndicatorRole] ;     lua_setfield(L, -2, "valueIndicator") ;
    [skin pushNSObject:(__bridge NSString *)kAXWindowRole] ;             lua_setfield(L, -2, "window") ;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
    [skin pushNSObject:NSAccessibilityLinkRole] ;                        lua_setfield(L, -2, "link") ;
    [skin pushNSObject:NSAccessibilityPageRole] ;                        lua_setfield(L, -2, "page") ;
#pragma clang diagnostic pop

    return 1 ;
}

/// hs.axuielement.subroles[]
/// Constant
/// A table of common accessibility object subroles which may be used with [hs.axuielement:elementSearch](#elementSearch) or [hs.axuielement:matchesCriteria](#matchesCriteria) as attribute values for "AXSubrole" in the match criteria argument.
///
/// Notes:
///  * this table is provided for reference only and is not intended to be comprehensive.
///  * you can view the contents of this table from the Hammerspoon console by typing in `hs.axuielement.subroles`
static int axuielement_pushSubrolesTable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kAXApplicationDockItemSubrole] ;     lua_setfield(L, -2, "applicationDockItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXCloseButtonSubrole] ;             lua_setfield(L, -2, "closeButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXContentListSubrole] ;             lua_setfield(L, -2, "contentList") ;
    [skin pushNSObject:(__bridge NSString *)kAXDecorativeSubrole] ;              lua_setfield(L, -2, "decorative") ;
    [skin pushNSObject:(__bridge NSString *)kAXDecrementArrowSubrole] ;          lua_setfield(L, -2, "decrementArrow") ;
    [skin pushNSObject:(__bridge NSString *)kAXDecrementPageSubrole] ;           lua_setfield(L, -2, "decrementPage") ;
    [skin pushNSObject:NSAccessibilityDefinitionListSubrole] ;                   lua_setfield(L, -2, "definitionList") ;
    [skin pushNSObject:(__bridge NSString *)kAXDescriptionListSubrole] ;         lua_setfield(L, -2, "descriptionList") ;
    [skin pushNSObject:(__bridge NSString *)kAXDialogSubrole] ;                  lua_setfield(L, -2, "dialog") ;
    [skin pushNSObject:(__bridge NSString *)kAXDockExtraDockItemSubrole] ;       lua_setfield(L, -2, "dockExtraDockItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXDocumentDockItemSubrole] ;        lua_setfield(L, -2, "documentDockItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXFloatingWindowSubrole] ;          lua_setfield(L, -2, "floatingWindow") ;
    [skin pushNSObject:(__bridge NSString *)kAXFolderDockItemSubrole] ;          lua_setfield(L, -2, "folderDockItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXFullScreenButtonSubrole] ;        lua_setfield(L, -2, "fullScreenButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXIncrementArrowSubrole] ;          lua_setfield(L, -2, "incrementArrow") ;
    [skin pushNSObject:(__bridge NSString *)kAXIncrementPageSubrole] ;           lua_setfield(L, -2, "incrementPage") ;
    [skin pushNSObject:(__bridge NSString *)kAXMinimizeButtonSubrole] ;          lua_setfield(L, -2, "minimizeButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXMinimizedWindowDockItemSubrole] ; lua_setfield(L, -2, "minimizedWindowDockItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXOutlineRowSubrole] ;              lua_setfield(L, -2, "outlineRow") ;
    [skin pushNSObject:(__bridge NSString *)kAXProcessSwitcherListSubrole] ;     lua_setfield(L, -2, "processSwitcherList") ;
    [skin pushNSObject:(__bridge NSString *)kAXRatingIndicatorSubrole] ;         lua_setfield(L, -2, "ratingIndicator") ;
    [skin pushNSObject:(__bridge NSString *)kAXSearchFieldSubrole] ;             lua_setfield(L, -2, "searchField") ;
    [skin pushNSObject:(__bridge NSString *)kAXSecureTextFieldSubrole] ;         lua_setfield(L, -2, "secureTextField") ;
    [skin pushNSObject:(__bridge NSString *)kAXSeparatorDockItemSubrole] ;       lua_setfield(L, -2, "separatorDockItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXSortButtonSubrole] ;              lua_setfield(L, -2, "sortButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXStandardWindowSubrole] ;          lua_setfield(L, -2, "standardWindow") ;
    [skin pushNSObject:(__bridge NSString *)kAXSwitchSubrole] ;                  lua_setfield(L, -2, "switch") ;
    [skin pushNSObject:(__bridge NSString *)kAXSystemDialogSubrole] ;            lua_setfield(L, -2, "systemDialog") ;
    [skin pushNSObject:(__bridge NSString *)kAXSystemFloatingWindowSubrole] ;    lua_setfield(L, -2, "systemFloatingWindow") ;
    [skin pushNSObject:(__bridge NSString *)kAXTableRowSubrole] ;                lua_setfield(L, -2, "tableRow") ;
    [skin pushNSObject:NSAccessibilityTextAttachmentSubrole] ;                   lua_setfield(L, -2, "textAttachment") ;
    [skin pushNSObject:NSAccessibilityTextLinkSubrole] ;                         lua_setfield(L, -2, "textLink") ;
    [skin pushNSObject:(__bridge NSString *)kAXTimelineSubrole] ;                lua_setfield(L, -2, "timeline") ;
    [skin pushNSObject:(__bridge NSString *)kAXToggleSubrole] ;                  lua_setfield(L, -2, "toggle") ;
    [skin pushNSObject:(__bridge NSString *)kAXToolbarButtonSubrole] ;           lua_setfield(L, -2, "toolbarButton") ;
    [skin pushNSObject:(__bridge NSString *)kAXTrashDockItemSubrole] ;           lua_setfield(L, -2, "trashDockItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXUnknownSubrole] ;                 lua_setfield(L, -2, "unknown") ;
    [skin pushNSObject:(__bridge NSString *)kAXURLDockItemSubrole] ;             lua_setfield(L, -2, "URLDockItem") ;
    [skin pushNSObject:(__bridge NSString *)kAXZoomButtonSubrole] ;              lua_setfield(L, -2, "zoomButton") ;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
    [skin pushNSObject:NSAccessibilityCollectionListSubrole] ;                   lua_setfield(L, -2, "collectionList") ;
    [skin pushNSObject:NSAccessibilityTabButtonSubrole] ;                        lua_setfield(L, -2, "tabButton") ;
    [skin pushNSObject:NSAccessibilitySectionListSubrole] ;                      lua_setfield(L, -2, "sectionList") ;
#pragma clang diagnostic pop

   return 1 ;
}

/// hs.axuielement.orientations[]
/// Constant
/// A table of orientation types which may be used with [hs.axuielement:elementSearch](#elementSearch) or [hs.axuielement:matchesCriteria](#matchesCriteria) as attribute values for "AXOrientation" in the match criteria argument.
///
/// Notes:
///  * this table is provided for reference only and may not be comprehensive.
///  * you can view the contents of this table from the Hammerspoon console by typing in `hs.axuielement.orientations`
static int axuielement_pushOrientationsTable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kAXHorizontalOrientationValue] ; lua_setfield(L, -2, "horizontal") ;
    [skin pushNSObject:(__bridge NSString *)kAXVerticalOrientationValue] ;   lua_setfield(L, -2, "vertical") ;
    [skin pushNSObject:(__bridge NSString *)kAXUnknownOrientationValue] ;    lua_setfield(L, -2, "unknown") ;
    return 1 ;
}

/// hs.axuielement.sortDirections[]
/// Constant
/// A table of sort direction types which may be used with [hs.axuielement:elementSearch](#elementSearch) or [hs.axuielement:matchesCriteria](#matchesCriteria) as attribute values for "AXSortDirection" in the match criteria argument.
///
/// Notes:
///  * this table is provided for reference only and may not be comprehensive.
///  * you can view the contents of this table from the Hammerspoon console by typing in `hs.axuielement.sortDirections`
static int axuielement_pushSortDirectionsTable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    lua_newtable(L) ;
    [skin pushNSObject:(__bridge NSString *)kAXAscendingSortDirectionValue] ;  lua_setfield(L, -2, "ascending") ;
    [skin pushNSObject:(__bridge NSString *)kAXDescendingSortDirectionValue] ; lua_setfield(L, -2, "descending") ;
    [skin pushNSObject:(__bridge NSString *)kAXUnknownSortDirectionValue] ;    lua_setfield(L, -2, "unknown") ;
    return 1 ;
}

/// hs.axuielement.rulerMarkers[]
/// Constant
/// A table of ruler marker types which may be used with [hs.axuielement:elementSearch](#elementSearch) or [hs.axuielement:matchesCriteria](#matchesCriteria) as attribute values for "AXMarkerType" in the match criteria argument.
///
/// Notes:
///  * this table is provided for reference only and may not be comprehensive.
///  * you can view the contents of this table from the Hammerspoon console by typing in `hs.axuielement.rulerMarkers`
static int axuielement_pushRulerMarkerTypesTable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    lua_newtable(L) ;
    [skin pushNSObject:NSAccessibilityCenterTabStopMarkerTypeValue] ;   lua_setfield(L, -2, "centerTabStop") ;
    [skin pushNSObject:NSAccessibilityDecimalTabStopMarkerTypeValue] ;  lua_setfield(L, -2, "decimalTabStop") ;
    [skin pushNSObject:NSAccessibilityFirstLineIndentMarkerTypeValue] ; lua_setfield(L, -2, "firstLineIndent") ;
    [skin pushNSObject:NSAccessibilityHeadIndentMarkerTypeValue] ;      lua_setfield(L, -2, "headIndent") ;
    [skin pushNSObject:NSAccessibilityLeftTabStopMarkerTypeValue] ;     lua_setfield(L, -2, "leftTabStop") ;
    [skin pushNSObject:NSAccessibilityRightTabStopMarkerTypeValue] ;    lua_setfield(L, -2, "rightTabStop") ;
    [skin pushNSObject:NSAccessibilityTailIndentMarkerTypeValue] ;      lua_setfield(L, -2, "tailIndent") ;
    [skin pushNSObject:NSAccessibilityUnknownMarkerTypeValue] ;         lua_setfield(L, -2, "unknown") ;
    return 1 ;
}

/// hs.axuielement.units[]
/// Constant
/// A table of measurement unit types which may be used with [hs.axuielement:elementSearch](#elementSearch) or [hs.axuielement:matchesCriteria](#matchesCriteria) as attribute values for attributes which specify measurement unit types (e.g. "AXUnits", "AXHorizontalUnits", and "AXVerticalUnits") in the match criteria argument.
///
/// Notes:
///  * this table is provided for reference only and may not be comprehensive.
///  * you can view the contents of this table from the Hammerspoon console by typing in `hs.axuielement.units`
static int axuielement_pushUnitsTable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    lua_newtable(L) ;
    [skin pushNSObject:NSAccessibilityCentimetersUnitValue] ; lua_setfield(L, -2, "centimeters") ;
    [skin pushNSObject:NSAccessibilityInchesUnitValue] ;      lua_setfield(L, -2, "inches") ;
    [skin pushNSObject:NSAccessibilityPicasUnitValue] ;       lua_setfield(L, -2, "picas") ;
    [skin pushNSObject:NSAccessibilityPointsUnitValue] ;      lua_setfield(L, -2, "points") ;
    [skin pushNSObject:NSAccessibilityUnknownUnitValue] ;     lua_setfield(L, -2, "unknown") ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    CFTypeRef value ;
    AXError errorState = AXUIElementCopyAttributeValue(theRef, (__bridge CFStringRef)@"AXRole", &value) ;
    NSString *title = @"*accessibility error*" ;
    if (errorState == kAXErrorSuccess) {
        title = (__bridge NSString *)value ;
    } else if (errorState == kAXErrorInvalidUIElement) {
        title = @"*element invalid*" ;
    }
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    if (value) CFRelease(value) ;
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    AXUIElementRef theRef = get_axuielementref(L, 1, USERDATA_TAG) ;
    CFRelease(theRef) ;
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int userdata_eq(lua_State* L) {
    AXUIElementRef theRef1 = get_axuielementref(L, 1, USERDATA_TAG) ;
    AXUIElementRef theRef2 = get_axuielementref(L, 2, USERDATA_TAG) ;
    lua_pushboolean(L, CFEqual(theRef1, theRef2)) ;
    return 1 ;
}

// static int meta_gc(lua_State* L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"attributeNames",              axuielement_getAttributeNames},
    {"allAttributeValues",          axuielement_getAllAttributeValues},
    {"parameterizedAttributeNames", axuielement_getParameterizedAttributeNames},
    {"actionNames",                 axuielement_getActionNames},
    {"actionDescription",           axuielement_getActionDescription},
    {"attributeValue",              axuielement_getAttributeValue},
    {"parameterizedAttributeValue", axuielement_getParameterizedAttributeValue},
    {"attributeValueCount",         axuielement_getAttributeValueCount},
    {"isAttributeSettable",         axuielement_isAttributeSettable},
    {"pid",                         axuielement_getPid},
    {"performAction",               axuielement_performAction},
    {"elementAtPosition",           axuielement_getElementAtPosition},
    {"setAttributeValue",           axuielement_setAttributeValue},
    {"asHSWindow",                  axuielement_toHSWindow},
    {"asHSApplication",             axuielement_toHSApplication},
    {"copy",                        axuielement_duplicateReference},
    {"setTimeout",                  axuielement_setTimeout},
    {"isValid",                     axuielement_isValid},

    {"__tostring",                  userdata_tostring},
    {"__eq",                        userdata_eq},
    {"__gc",                        userdata_gc},
    {NULL,                          NULL}
} ;

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"systemWideElement",        axuielement_getSystemWideElement},
    {"windowElement",            axuielement_getWindowElement},
    {"applicationElement",       axuielement_getApplicationElement},
    {"applicationElementForPID", axuielement_getApplicationElementForPID},

    {NULL,                       NULL}
} ;

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// } ;

int luaopen_hs_libaxuielement(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib] ;

    luaopen_hs_libaxuielementobserver(L) ;     lua_setfield(L, -2, "observer") ;
    luaopen_hs_axuielement_axtextmarker(L) ; lua_setfield(L, -2, "axtextmarker") ;

// For reference, since the object __init wrapper in init.lua and the keys for elementSearch don't
// actually use them in case the user wants to use an Application defined attribute or action not
// defined in the OS X headers.
    axuielement_pushAttributesTable(L) ;              lua_setfield(L, -2, "attributes") ;
    axuielement_pushParamaterizedAttributesTable(L) ; lua_setfield(L, -2, "parameterizedAttributes") ;
    axuielement_pushActionsTable(L) ;                 lua_setfield(L, -2, "actions") ;

// ditto on these, since they are are actually results, not query-able parameters or actionable
// commands; however they can be used with elementSearch as values in the criteria to find such.
    axuielement_pushRolesTable(L) ;                   lua_setfield(L, -2, "roles") ;
    axuielement_pushSubrolesTable(L) ;                lua_setfield(L, -2, "subroles") ;
    axuielement_pushSortDirectionsTable(L) ;          lua_setfield(L, -2, "sortDirections") ;
    axuielement_pushOrientationsTable(L) ;            lua_setfield(L, -2, "orientations") ;
    axuielement_pushRulerMarkerTypesTable(L) ;        lua_setfield(L, -2, "rulerMarkers") ;
    axuielement_pushUnitsTable(L) ;                   lua_setfield(L, -2, "units") ;

    return 1 ;
}
