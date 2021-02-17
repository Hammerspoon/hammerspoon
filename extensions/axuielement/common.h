#pragma once

@import Cocoa ;
@import LuaSkin ;

#import "ExternalReferences.h"

#define USERDATA_TAG     "hs.axuielement"
#define OBSERVER_TAG     "hs.axuielement.observer"
#define AXTEXTMARKER_TAG "hs.axuielement.axtextmarker"
#define AXTEXTMRKRNG_TAG "hs.axuielement.axtextmarkerrange"

#define get_axuielementref(L, idx, tag) *((AXUIElementRef*)luaL_checkudata(L, idx, tag))
#define get_axobserverref(L, idx, tag) *((AXObserverRef*)luaL_checkudata(L, idx, tag))
#define get_axtextmarkerref(L, idx, tag) *((AXTextMarkerRef*)luaL_checkudata(L, idx, tag))
#define get_axtextmarkerrangeref(L, idx, tag) *((AXTextMarkerRangeRef*)luaL_checkudata(L, idx, tag))

extern AXUIElementRef getElementRefPropertyFromClassObject(NSObject *object) ;

extern BOOL new_application(lua_State* L, pid_t pid) ;
extern BOOL new_window(lua_State* L, AXUIElementRef win) ;

extern int pushAXUIElement(lua_State *L, AXUIElementRef theElement) ;
extern int pushAXObserver(lua_State *L, AXObserverRef theObserver) ;
extern int pushAXTextMarker(lua_State *L, AXTextMarkerRef theElement) ;
extern int pushAXTextMarkerRange(lua_State *L, AXTextMarkerRangeRef theElement) ;

extern const char *AXErrorAsString(AXError theError) ;

extern int pushCFTypeToLua(lua_State *L, CFTypeRef theItem, LSRefTable refTable) ;
extern CFTypeRef lua_toCFType(lua_State *L, int idx) ;

int luaopen_hs_axuielement_observer(lua_State* L) ;
int luaopen_hs_axuielement_axtextmarker(lua_State* L) ;
