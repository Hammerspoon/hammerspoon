#import "common.h"

// keep this current with Hammerspoon's method for creating new hs.application and hs.window objects

@protocol PlaceHoldersHSuicoreMethods
- (NSObject *)initWithPid:(pid_t)pid withState:(lua_State *)L ;
- (NSObject *)initWithAXUIElementRef:(AXUIElementRef)winRef ;
@end

extern AXError _AXUIElementGetWindow(AXUIElementRef, CGWindowID* out) ;

AXUIElementRef getElementRefPropertyFromClassObject(NSObject *object) {
    AXUIElementRef ref      = NULL ;
    SEL            selector = NSSelectorFromString(@"elementRef") ;

    if ([object respondsToSelector:selector]) {
        NSMethodSignature *signature  = [NSMethodSignature signatureWithObjCTypes:"^{__AXUIElement=}16@0:8"] ;
        NSInvocation      *invocation = [NSInvocation invocationWithMethodSignature:signature] ;
        [invocation setTarget:object] ;
        [invocation setSelector:selector] ;
        [invocation invoke] ;
        [invocation getReturnValue:&ref] ;
        if (ref) CFRetain(ref) ;
    }
    return ref ;
}

BOOL new_application(lua_State* L, pid_t pid) {
    BOOL isGood = false ;
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    Class HSA = NSClassFromString(@"HSapplication") ;
    if (HSA) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-messaging-id"
        NSObject *obj = [[HSA alloc] initWithPid:pid withState:L] ;
#pragma clang diagnostic pop
        if (obj) {
            [skin pushNSObject:obj] ;
            isGood = true ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        [skin logError:[NSString stringWithFormat:@"%s:new_application - HSapplication class not present; may require Hammerspoon upgrade", USERDATA_TAG]] ;
        lua_pushnil(L) ;
    }
    return isGood ;
}

BOOL new_window(lua_State* L, AXUIElementRef win) {
    BOOL isGood = false ;
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    Class HSW = NSClassFromString(@"HSwindow") ;
    if (HSW) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-messaging-id"
        NSObject *obj = [[HSW alloc] initWithAXUIElementRef:win] ;
#pragma clang diagnostic pop
        if (obj) {
            // the HSapplication initializer retains its elementRef; the HSwindow one doesn't
            CFRetain(win) ;
            [skin pushNSObject:obj] ;
            isGood = true ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        [skin logError:[NSString stringWithFormat:@"%s:new_window - HSapplication class not present; may require Hammerspoon upgrade", USERDATA_TAG]] ;
        lua_pushnil(L) ;
    }
    return isGood ;
}

// Not sure if the alreadySeen trick is working here, but it hasn't crashed yet... of course I don't think I've found any loops that don't have a userdata object in-between that drops us back to Lua before deciding whether or not to delve deeper, either, so... should be safe in CFDictionary and CFArray, since they toll-free bridge; don't use for others -- fails for setting with AXUIElementRef as key, at least...

static int pushCFTypeHamster(lua_State *L, CFTypeRef theItem, NSMutableDictionary *alreadySeen, LSRefTable refTable) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    if (!theItem) {
        lua_pushnil(L) ;
        return 1 ;
    }

    CFTypeID theType = CFGetTypeID(theItem) ;
    if      (theType == CFArrayGetTypeID()) {
        NSNumber *seenRef = alreadySeen[(__bridge id)theItem] ;
        if (seenRef) {
            [skin pushLuaRef:refTable ref:seenRef.intValue] ;
            return 1 ;
        }
        lua_newtable(L) ;
        seenRef = [NSNumber numberWithInt:[skin luaRef:refTable]] ;
        alreadySeen[(__bridge id)theItem] = seenRef ;
        [skin pushLuaRef:refTable ref:seenRef.intValue] ; // put it back on the stack
        for(id thing in (__bridge NSArray *)theItem) {
            pushCFTypeHamster(L, (__bridge CFTypeRef)thing, alreadySeen, refTable) ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    } else if (theType == CFDictionaryGetTypeID()) {
        NSNumber *seenRef = alreadySeen[(__bridge id)theItem] ;
        if (seenRef) {
            [skin pushLuaRef:refTable ref:seenRef.intValue] ;
            return 1 ;
        }
        lua_newtable(L) ;
        seenRef = [NSNumber numberWithInt:[skin luaRef:refTable]] ;
        alreadySeen[(__bridge id)theItem] = seenRef ;
        [skin pushLuaRef:refTable ref:seenRef.intValue] ; // put it back on the stack
        NSArray *keys = [(__bridge NSDictionary *)theItem allKeys] ;
        NSArray *values = [(__bridge NSDictionary *)theItem allValues] ;
        for (unsigned long i = 0 ; i < [keys count] ; i++) {
            pushCFTypeHamster(L, (__bridge CFTypeRef)[keys objectAtIndex:i], alreadySeen, refTable) ;
            pushCFTypeHamster(L, (__bridge CFTypeRef)[values objectAtIndex:i], alreadySeen, refTable) ;
            lua_settable(L, -3) ;
        }
    } else if (theType == AXValueGetTypeID()) {
        AXValueType valueType = AXValueGetType((AXValueRef)theItem) ;
        if (valueType == kAXValueCGPointType) {
            CGPoint thePoint ;
            AXValueGetValue((AXValueRef)theItem, kAXValueCGPointType, &thePoint) ;
            lua_newtable(L) ;
              lua_pushnumber(L, thePoint.x) ; lua_setfield(L, -2, "x") ;
              lua_pushnumber(L, thePoint.y) ; lua_setfield(L, -2, "y") ;
        } else if (valueType == kAXValueCGSizeType) {
            CGSize theSize ;
            AXValueGetValue((AXValueRef)theItem, kAXValueCGSizeType, &theSize) ;
            lua_newtable(L) ;
              lua_pushnumber(L, theSize.height) ; lua_setfield(L, -2, "h") ;
              lua_pushnumber(L, theSize.width) ;  lua_setfield(L, -2, "w") ;
        } else if (valueType == kAXValueCGRectType) {
            CGRect theRect ;
            AXValueGetValue((AXValueRef)theItem, kAXValueCGRectType, &theRect) ;
            lua_newtable(L) ;
              lua_pushnumber(L, theRect.origin.x) ;    lua_setfield(L, -2, "x") ;
              lua_pushnumber(L, theRect.origin.y) ;    lua_setfield(L, -2, "y") ;
              lua_pushnumber(L, theRect.size.height) ; lua_setfield(L, -2, "h") ;
              lua_pushnumber(L, theRect.size.width) ;  lua_setfield(L, -2, "w") ;
        } else if (valueType == kAXValueCFRangeType) {
            CFRange theRange ;
            AXValueGetValue((AXValueRef)theItem, kAXValueCFRangeType, &theRange) ;
            lua_newtable(L) ;
              lua_pushinteger(L, theRange.location) ; lua_setfield(L, -2, "location") ;
              lua_pushinteger(L, theRange.length) ;   lua_setfield(L, -2, "length") ;
        } else if (valueType == kAXValueAXErrorType) {
            AXError theError ;
            AXValueGetValue((AXValueRef)theItem, kAXValueAXErrorType, &theError) ;
            lua_newtable(L) ;
              lua_pushinteger(L, theError) ;                 lua_setfield(L, -2, "_code") ;
              lua_pushstring(L, AXErrorAsString(theError)) ; lua_setfield(L, -2, "error") ;
//         } else if (valueType == kAXValueIllegalType) {
        } else {
            lua_pushfstring(L, "unrecognized value type (%p)", theItem) ;
        }
    } else if (theType == CGColorGetTypeID()) {
        [skin pushNSObject:[NSColor colorWithCGColor:(CGColorRef)theItem]] ;
    } else if (theType == CGImageGetTypeID()) {
        NSSize imageSize = NSMakeSize(CGImageGetWidth((CGImageRef)theItem), CGImageGetHeight((CGImageRef)theItem)) ;
        [skin pushNSObject:[[NSImage alloc] initWithCGImage:(CGImageRef)theItem size:imageSize]] ;
    } else if (theType == CFAttributedStringGetTypeID()) {
        [skin pushNSObject:(__bridge NSAttributedString *)theItem] ;
    } else if (theType == CFNullGetTypeID()) {
        [skin pushNSObject:(__bridge NSNull *)theItem] ;
    } else if (theType == CFBooleanGetTypeID() || theType == CFNumberGetTypeID()) {
        [skin pushNSObject:(__bridge NSNumber *)theItem] ;
    } else if (theType == CFDataGetTypeID()) {
        [skin pushNSObject:(__bridge NSData *)theItem] ;
    } else if (theType == CFDateGetTypeID()) {
        [skin pushNSObject:(__bridge NSDate *)theItem] ;
    } else if (theType == CFStringGetTypeID()) {
        [skin pushNSObject:(__bridge NSString *)theItem] ;
    } else if (theType == CFURLGetTypeID()) {
        [skin pushNSObject:(__bridge NSURL *)theItem] ;
    } else if (theType == AXUIElementGetTypeID()) {
        pushAXUIElement(L, theItem) ;
    } else if (theType == AXObserverGetTypeID()) {
        pushAXObserver(L, (AXObserverRef)theItem) ;
    } else if (AXTextMarkerGetTypeID != NULL      && theType == AXTextMarkerGetTypeID()) {
        pushAXTextMarker(L, theItem) ;
    } else if (AXTextMarkerRangeGetTypeID != NULL && theType == AXTextMarkerRangeGetTypeID()) {
        pushAXTextMarkerRange(L, theItem) ;
    } else {
          NSString *typeLabel = [NSString stringWithFormat:@"unrecognized type: %lu", theType] ;
          [skin logDebug:[NSString stringWithFormat:@"%s:%@", USERDATA_TAG, typeLabel]];
          lua_pushstring(L, [typeLabel UTF8String]) ;
      }
    return 1 ;
}

static CFTypeRef lua_toCFTypeHamster(lua_State *L, int idx, NSMutableDictionary *seen) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    int index = lua_absindex(L, idx) ;

    CFTypeRef value = kCFNull ;

    if (seen[[NSValue valueWithPointer:lua_topointer(L, index)]]) {
        [skin logWarn:[NSString stringWithFormat:@"%s:multiple references to same table not currently supported for conversion", USERDATA_TAG]] ;
        return kCFNull ;
        // once I figure out (a) if we want to support this,
        //                   (b) if we should add a flag like we do for LuaSkin's NS version,
        //               and (c) the best way to store a CFTypeRef in an NSDictionary
        // value = CFRetain(pull CFTypeRef from @{seen}) ;
    } else if (lua_absindex(L, lua_gettop(L)) >= index) {
        int theType = lua_type(L, index) ;
        if (theType == LUA_TSTRING) {
            NSObject *holder = [skin toNSObjectAtIndex:index] ;
            if ([holder isKindOfClass:[NSString class]]) {
                value = (__bridge_retained CFStringRef)holder ;
            } else {
                value = (__bridge_retained CFDataRef)holder ;
            }
        } else if (theType == LUA_TBOOLEAN) {
            value = lua_toboolean(L, index) ? kCFBooleanTrue : kCFBooleanFalse ;
        } else if (theType == LUA_TNUMBER) {
            if (lua_isinteger(L, index)) {
                lua_Integer holder = lua_tointeger(L, index) ;
                value = CFNumberCreate(kCFAllocatorDefault, kCFNumberLongLongType, &holder) ;
            } else {
                lua_Number holder = lua_tonumber(L, index) ;
                value = CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &holder) ;
            }
        } else if (theType == LUA_TTABLE) {
        // for object LuaSkin types
            BOOL has__luaSkinType = (lua_getfield(L, index, "__luaSkinType") != LUA_TNIL) ; lua_pop(L, 1) ;

        // rect, point, and size are regularly tables in Hammerspoon, differentiated by which of these
        // keys are present.
            BOOL hasX      = (lua_getfield(L, index, "x")        != LUA_TNIL) ; lua_pop(L, 1) ;
            BOOL hasY      = (lua_getfield(L, index, "y")        != LUA_TNIL) ; lua_pop(L, 1) ;
            BOOL hasH      = (lua_getfield(L, index, "h")        != LUA_TNIL) ; lua_pop(L, 1) ;
            BOOL hasW      = (lua_getfield(L, index, "w")        != LUA_TNIL) ; lua_pop(L, 1) ;
        // objc-style indexing for range
            BOOL hasLoc    = (lua_getfield(L, index, "location") != LUA_TNIL) ; lua_pop(L, 1) ;
            BOOL hasLen    = (lua_getfield(L, index, "length")   != LUA_TNIL) ; lua_pop(L, 1) ;
        // lua-style indexing for range
            BOOL hasStarts = (lua_getfield(L, index, "starts")   != LUA_TNIL) ; lua_pop(L, 1) ;
            BOOL hasEnds   = (lua_getfield(L, index, "ends")     != LUA_TNIL) ; lua_pop(L, 1) ;
        // AXError type
            BOOL hasError  = (lua_getfield(L, index, "_code")    != LUA_TNIL) ; lua_pop(L, 1) ;
        // since date is just a number or string, we'll have to make it a "psuedo" table so that it can
        // be uniquely specified on the lua side
            BOOL hasDate   = (lua_getfield(L, index, "_date")    != LUA_TNIL) ; lua_pop(L, 1) ;

            // check these first because range, rect, point, and size also have __luaSkinType versions with NSValue, but that's a pain
            // to convert to AXTypeRef plus not all methods return them *with* the __luaSkinType field set so we'd have to double up
            // on the checks anyways...
            if (hasX && hasY && hasH && hasW) { // CGRect
                lua_getfield(L, index, "x") ;
                lua_getfield(L, index, "y") ;
                lua_getfield(L, index, "w") ;
                lua_getfield(L, index, "h") ;
                CGRect holder = CGRectMake(luaL_checknumber(L, -4), luaL_checknumber(L, -3), luaL_checknumber(L, -2), luaL_checknumber(L, -1)) ;
                value = AXValueCreate(kAXValueCGRectType, &holder) ;
                lua_pop(L, 4) ;
            } else if (hasX && hasY) {          // CGPoint
                lua_getfield(L, index, "x") ;
                lua_getfield(L, index, "y") ;
                CGPoint holder = CGPointMake(luaL_checknumber(L, -2), luaL_checknumber(L, -1)) ;
                value = AXValueCreate(kAXValueCGPointType, &holder) ;
                lua_pop(L, 2) ;
            } else if (hasH && hasW) {          // CGSize
                lua_getfield(L, index, "w") ;
                lua_getfield(L, index, "h") ;
                CGSize holder = CGSizeMake(luaL_checknumber(L, -2), luaL_checknumber(L, -1)) ;
                value = AXValueCreate(kAXValueCGSizeType, &holder) ;
                lua_pop(L, 2) ;
            } else if (hasLoc && hasLen) {      // CFRange objc style
                lua_getfield(L, index, "location") ;
                lua_getfield(L, index, "length") ;
                CFRange holder = CFRangeMake(luaL_checkinteger(L, -2), luaL_checkinteger(L, -1)) ;
                value = AXValueCreate(kAXValueCFRangeType, &holder) ;
                lua_pop(L, 2) ;
            } else if (hasStarts && hasEnds) {  // CFRange lua style
// NOTE: Negative indexes and UTF8 as bytes can't be handled here without context.
//       Maybe on lua side in wrapper functions?
                lua_getfield(L, index, "starts") ;
                lua_getfield(L, index, "ends") ;
                lua_Integer starts = luaL_checkinteger(L, -2) ;
                lua_Integer ends   = luaL_checkinteger(L, -1) ;
                CFRange holder = CFRangeMake(starts - 1, ends + 1 - starts) ;
                value = AXValueCreate(kAXValueCFRangeType, &holder) ;
                lua_pop(L, 2) ;
            } else if (hasError) {              // AXError
                lua_getfield(L, index, "_code") ;
                AXError holder = (AXError)(unsigned long long)luaL_checkinteger(L, -1) ;
                value = AXValueCreate(kAXValueAXErrorType, &holder) ;
                lua_pop(L, 1) ;
            } else if (hasDate) {               // CFDate
                int dateType = lua_getfield(L, index, "_date") ;
                if (dateType == LUA_TNUMBER) {
                    value = CFDateCreate(kCFAllocatorDefault, [[NSDate dateWithTimeIntervalSince1970:lua_tonumber(L, -1)] timeIntervalSinceReferenceDate]) ;
                } else if (dateType == LUA_TSTRING) {
                    // rfc3339 (Internet Date/Time) formated date.  More or less.
                    NSDateFormatter *rfc3339DateFormatter = [[NSDateFormatter alloc] init] ;
                    NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] ;
                    [rfc3339DateFormatter setLocale:enUSPOSIXLocale] ;
                    [rfc3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"] ;
                    [rfc3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]] ;
                    value = (__bridge_retained CFDateRef)[rfc3339DateFormatter dateFromString:[skin toNSObjectAtIndex:-1]] ;
                } else {
                    lua_pop(L, 1) ;
                    [skin logError:[NSString stringWithFormat:@"%s:invalid date format specified for conversion", USERDATA_TAG]] ;
                    return kCFNull ;
                }
                lua_pop(L, 1) ;
            } else if (has__luaSkinType) {
                NSObject *object = [skin toNSObjectAtIndex:index] ;
                if ([object isKindOfClass:[NSColor class]])                 { value = CFRetain([(NSColor *)object CGColor]) ; }
                else if ([object isKindOfClass:[NSURL class]])              { value = (__bridge_retained CFURLRef)object ; }
                else if ([object isKindOfClass:[NSImage class]])            { value = CFRetain([(NSImage *)object CGImageForProposedRect:NULL context:nil hints:nil]) ; }
                else if ([object isKindOfClass:[NSAttributedString class]]) { value = (__bridge_retained CFAttributedStringRef)object ; }
                else {
                    lua_getfield(L, index, "__luaSkinType") ;
                    [skin logError:[NSString stringWithFormat:@"%s:__luaSkinType table %s not supported for conversion", USERDATA_TAG, lua_tostring(L, -1)]] ;
                    lua_pop(L, 1) ;
                    return kCFNull ;
                }
            } else {                            // real CFDictionary or CFArray
              seen[[NSValue valueWithPointer:lua_topointer(L, index)]] = @(YES) ;
              if (luaL_len(L, index) == [skin countNatIndex:index]) { // CFArray
                  CFMutableArrayRef holder = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks) ;
                  for (lua_Integer i = 0 ; i < luaL_len(L, index) ; i++ ) {
                      lua_geti(L, index, i + 1) ;
                      CFTypeRef theVal = lua_toCFTypeHamster(L, -1, seen) ;
                      CFArrayAppendValue(holder, theVal) ;
                      if (theVal) CFRelease(theVal) ;
                      lua_pop(L, 1) ;
                  }
                  value = holder ;
              } else {                                      // CFDictionary
                  CFMutableDictionaryRef holder = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks) ;
                  lua_pushnil(L) ;
                  while (lua_next(L, index) != 0) {
                      CFTypeRef theKey = lua_toCFTypeHamster(L, -2, seen) ;
                      CFTypeRef theVal = lua_toCFTypeHamster(L, -1, seen) ;
                      CFDictionarySetValue(holder, theKey, theVal) ;
                      if (theKey) CFRelease(theKey) ;
                      if (theVal) CFRelease(theVal) ;
                      lua_pop(L, 1) ;
                  }
                  value = holder ;
              }
            }
        } else if (theType == LUA_TUSERDATA) {
            if (luaL_testudata(L, index, "hs.styledtext"))       { value = (__bridge_retained CFAttributedStringRef)[skin toNSObjectAtIndex:index] ; }
            else if (luaL_testudata(L, index, USERDATA_TAG))     { value = CFRetain(get_axuielementref(L, index, USERDATA_TAG)) ; }
            else if (luaL_testudata(L, index, OBSERVER_TAG))     { value = CFRetain(get_axobserverref(L, index, OBSERVER_TAG)) ; }
            else if (luaL_testudata(L, index, AXTEXTMARKER_TAG)) { value = CFRetain(get_axtextmarkerref(L, index, AXTEXTMARKER_TAG)) ; }
            else if (luaL_testudata(L, index, AXTEXTMRKRNG_TAG)) { value = CFRetain(get_axtextmarkerrangeref(L, index, AXTEXTMRKRNG_TAG)) ; }
            else {
                [skin logError:[NSString stringWithFormat:@"%s:unrecognized userdata is not supported for conversion", USERDATA_TAG]] ;
                return kCFNull ;
            }
        } else if (theType != LUA_TNIL) { // value already set to kCFNull, no specific match necessary
            [skin logError:[NSString stringWithFormat:@"%s:type %s not supported for conversion", USERDATA_TAG, lua_typename(L, theType)]] ;
            return kCFNull ;
        }
    }
    return value ;
}

int pushCFTypeToLua(lua_State *L, CFTypeRef theItem, LSRefTable refTable) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    NSMutableDictionary *alreadySeen = [[NSMutableDictionary alloc] init] ;
    pushCFTypeHamster(L, theItem, alreadySeen, refTable) ;
    for (id entry in alreadySeen) {
        NSNumber *seenRef = alreadySeen[entry] ;
        [skin luaUnref:refTable ref:seenRef.intValue] ;
    }
    return 1 ;
}

CFTypeRef lua_toCFType(lua_State *L, int idx) {
    NSMutableDictionary *seen = [[NSMutableDictionary alloc] init] ;
    return lua_toCFTypeHamster(L, idx, seen) ;
}
