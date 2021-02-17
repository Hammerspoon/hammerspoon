@import Cocoa ;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wauto-import"
@import LuaSkin ;
#pragma clang diagnostic pop

static const char *USERDATA_TAG = "hs.canvas.matrix" ;
static LSRefTable refTable = LUA_NOREF;

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

/// hs.canvas.matrix.identity() -> matrixObject
/// Constructor
/// Specifies the identity matrix.  Resets all existing transformations when applied as a method to an existing matrixObject.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the identity matrix.
///
/// Notes:
///  * The identity matrix can be thought of as "apply no transformations at all" or "render as specified".
///  * Mathematically this is represented as:
/// ~~~
/// [ 1,  0,  0 ]
/// [ 0,  1,  0 ]
/// [ 0,  0,  1 ]
/// ~~~
static int matrix_identity(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL,
                    LS_TBREAK] ;
    [skin pushNSObject:[NSAffineTransform transform]] ;
    return 1;
}

#pragma mark - Module Methods

/// hs.canvas.matrix:invert() -> matrixObject
/// Method
/// Generates the mathematical inverse of the matrix.  This method cannot be used as a constructor.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the inverted matrix.
///
/// Notes:
///  * Inverting a matrix which represents a series of transformations has the effect of reversing or undoing the original transformations.
///  * This is useful when used with [hs.canvas.matrix.append](#append) to undo a previously applied transformation without actually replacing all of the transformations which may have been applied to a canvas element.
static int matrix_invert(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE,
                    LS_TBREAK] ;
    NSAffineTransform *transform = [skin luaObjectAtIndex:1 toClass:"NSAffineTransform"] ;
    [transform invert] ;
    [skin pushNSObject:transform] ;
    return 1 ;
}

/// hs.canvas.matrix:append(matrix) -> matrixObject
/// Method
/// Appends the specified matrix transformations to the matrix and returns the new matrix.  This method cannot be used as a constructor.
///
/// Parameters:
///  * `matrix` - the table to append to the current matrix.
///
/// Returns:
///  * the new matrix
///
/// Notes:
///  * Mathematically this method multiples the original matrix by the new one and returns the result of the multiplication.
///  * You can use this method to "stack" additional transformations on top of existing transformations, without having to know what the existing transformations in effect for the canvas element are.
static int matrix_append(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE,
                    LS_TTABLE,
                    LS_TBREAK] ;
    NSAffineTransform *transform1 = [skin luaObjectAtIndex:1 toClass:"NSAffineTransform"] ;
    NSAffineTransform *transform2 = [skin luaObjectAtIndex:2 toClass:"NSAffineTransform"] ;
    [transform1 appendTransform:transform2] ;
    [skin pushNSObject:transform1] ;
    return 1 ;
}

/// hs.canvas.matrix:prepend(matrix) -> matrixObject
/// Method
/// Prepends the specified matrix transformations to the matrix and returns the new matrix.  This method cannot be used as a constructor.
///
/// Parameters:
///  * `matrix` - the table to append to the current matrix.
///
/// Returns:
///  * the new matrix
///
/// Notes:
///  * Mathematically this method multiples the new matrix by the original one and returns the result of the multiplication.
///  * You can use this method to apply a transformation *before* the currently applied transformations, without having to know what the existing transformations in effect for the canvas element are.
static int matrix_prepend(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE,
                    LS_TTABLE,
                    LS_TBREAK] ;
    NSAffineTransform *transform1 = [skin luaObjectAtIndex:1 toClass:"NSAffineTransform"] ;
    NSAffineTransform *transform2 = [skin luaObjectAtIndex:2 toClass:"NSAffineTransform"] ;
    [transform1 prependTransform:transform2] ;
    [skin pushNSObject:transform1] ;
    return 1 ;
}

/// hs.canvas.matrix:rotate(angle) -> matrixObject
/// Method
/// Applies a rotation of the specified number of degrees to the transformation matrix.  This method can be used as a constructor or a method.
///
/// Parameters:
///  * `angle` - the number of degrees to rotate in a clockwise direction.
///
/// Returns:
///  * the new matrix
///
/// Notes:
///  * The rotation of an element this matrix is applied to will be rotated about the origin (zero point).  To rotate an object about another point (its center for example), prepend a translation to the point to rotate about, and append a translation reversing the initial translation.
///    * e.g. `hs.canvas.matrix.translate(x, y):rotate(angle):translate(-x, -y)`
static int matrix_rotate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSAffineTransform *transform = [NSAffineTransform transform] ;
    int argsAt = 2 ;
    if (lua_type(L, 1) == LUA_TNUMBER) {
        [skin checkArgs:LS_TNUMBER,
                        LS_TBREAK] ;
        argsAt = 1 ;
    } else {
        [skin checkArgs:LS_TTABLE,
                        LS_TNUMBER,
                        LS_TBREAK] ;
        transform = [skin luaObjectAtIndex:1 toClass:"NSAffineTransform"] ;
    }
    [transform rotateByDegrees:lua_tonumber(L, argsAt)] ;
    [skin pushNSObject:transform] ;
    return 1 ;
}

/// hs.canvas.matrix:scale(xFactor, [yFactor]) -> matrixObject
/// Method
/// Applies a scaling transformation to the matrix.  This method can be used as a constructor or a method.
///
/// Parameters:
///  * `xFactor` - the scaling factor to apply to the object in the horizontal orientation.
///  * `yFactor` - an optional argument specifying a different scaling factor in the vertical orientation.  If this argument is not provided, the `xFactor` argument will be used for both orientations.
///
/// Returns:
///  * the new matrix
static int matrix_scale(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSAffineTransform *transform = [NSAffineTransform transform] ;
    int argsAt = 2 ;
    if (lua_type(L, 1) == LUA_TNUMBER) {
        [skin checkArgs:LS_TNUMBER,
                        LS_TNUMBER | LS_TOPTIONAL,
                        LS_TBREAK] ;
        argsAt = 1 ;
    } else {
        [skin checkArgs:LS_TTABLE,
                        LS_TNUMBER,
                        LS_TNUMBER | LS_TOPTIONAL,
                        LS_TBREAK] ;
        transform = [skin luaObjectAtIndex:1 toClass:"NSAffineTransform"] ;
    }
    CGFloat scaleX = lua_tonumber(L, argsAt) ;
    CGFloat scaleY = (lua_gettop(L) == (argsAt + 1)) ? lua_tonumber(L, (argsAt + 1)) : scaleX ;
    [transform scaleXBy:scaleX yBy:scaleY] ;
    [skin pushNSObject:transform] ;
    return 1 ;
}

/// hs.canvas.matrix:shear(xFactor, [yFactor]) -> matrixObject
/// Method
/// Applies a shearing transformation to the matrix.  This method can be used as a constructor or a method.
///
/// Parameters:
///  * `xFactor` - the shearing factor to apply to the object in the horizontal orientation.
///  * `yFactor` - an optional argument specifying a different shearing factor in the vertical orientation.  If this argument is not provided, the `xFactor` argument will be used for both orientations.
///
/// Returns:
///  * the new matrix
static int matrix_shear(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSAffineTransform *transform = [NSAffineTransform transform] ;
    int argsAt = 2 ;
    if (lua_type(L, 1) == LUA_TNUMBER) {
        [skin checkArgs:LS_TNUMBER,
                        LS_TNUMBER | LS_TOPTIONAL,
                        LS_TBREAK] ;
        argsAt = 1 ;
    } else {
        [skin checkArgs:LS_TTABLE,
                        LS_TNUMBER,
                        LS_TNUMBER | LS_TOPTIONAL,
                        LS_TBREAK] ;
        transform = [skin luaObjectAtIndex:1 toClass:"NSAffineTransform"] ;
    }
    CGFloat shearX = lua_tonumber(L, argsAt) ;
    CGFloat shearY = (lua_gettop(L) == (argsAt + 1)) ? lua_tonumber(L, (argsAt + 1)) : shearX ;

    NSAffineTransform       *operation = [NSAffineTransform transform] ;
    NSAffineTransformStruct opStruct   = [operation transformStruct] ;
    opStruct.m12 = shearX ;
    opStruct.m21 = shearY ;
    [operation setTransformStruct:opStruct] ;
    [transform appendTransform:operation] ;
    [skin pushNSObject:transform] ;
    return 1 ;
}

/// hs.canvas.matrix:translate(x, y) -> matrixObject
/// Method
/// Applies a translation transformation to the matrix.  This method can be used as a constructor or a method.
///
/// Parameters:
///  * `x` - the distance to translate the object in the horizontal direction.
///  * `y` - the distance to translate the object in the vertical direction.
///
/// Returns:
///  * the new matrix
static int matrix_translate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSAffineTransform *transform = [NSAffineTransform transform] ;
    int argsAt = 2 ;
    if (lua_type(L, 1) == LUA_TNUMBER) {
        [skin checkArgs:LS_TNUMBER,
                        LS_TNUMBER | LS_TOPTIONAL,
                        LS_TBREAK] ;
        argsAt = 1 ;
    } else {
        [skin checkArgs:LS_TTABLE,
                        LS_TNUMBER,
                        LS_TNUMBER | LS_TOPTIONAL,
                        LS_TBREAK] ;
        transform = [skin luaObjectAtIndex:1 toClass:"NSAffineTransform"] ;
    }
    CGFloat translateX = lua_tonumber(L, argsAt) ;
    CGFloat translateY = (lua_gettop(L) == (argsAt + 1)) ? lua_tonumber(L, (argsAt + 1)) : translateX ;
    [transform translateXBy:translateX yBy:translateY] ;
    [skin pushNSObject:transform] ;
    return 1 ;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions

static int pushNSAffineTransform(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    if ([obj isKindOfClass:[NSAffineTransform class]]) {
        NSAffineTransformStruct structure = [(NSAffineTransform *)obj transformStruct] ;
        lua_newtable(L) ;
          lua_pushnumber(L, structure.m11) ; lua_setfield(L, -2, "m11") ;
          lua_pushnumber(L, structure.m12) ; lua_setfield(L, -2, "m12") ;
          lua_pushnumber(L, structure.m21) ; lua_setfield(L, -2, "m21") ;
          lua_pushnumber(L, structure.m22) ; lua_setfield(L, -2, "m22") ;
          lua_pushnumber(L, structure.tX) ;  lua_setfield(L, -2, "tX") ;
          lua_pushnumber(L, structure.tY) ;  lua_setfield(L, -2, "tY") ;
          lua_pushstring(L, "NSAffineTransform") ; lua_setfield(L, -2, "__luaSkinType") ;

        luaL_getmetatable(L, USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected NSAffineTransform, found %@",
                                                   [obj className]]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

static id toNSAffineTransformFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSAffineTransform  *value = [NSAffineTransform transform] ;
    NSAffineTransformStruct structure = [value transformStruct] ;
    if (lua_type(L, idx) == LUA_TTABLE) {
        idx = lua_absindex(L, idx) ;
        if (lua_getfield(L, idx, "m11") == LUA_TNUMBER) {
            structure.m11 = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"NSAffineTransform field m11 is not a number"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m12") == LUA_TNUMBER) {
            structure.m12 = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"NSAffineTransform field m12 is not a number"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m21") == LUA_TNUMBER) {
            structure.m21 = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"NSAffineTransform field m21 is not a number"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m22") == LUA_TNUMBER) {
            structure.m22 = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"NSAffineTransform field m22 is not a number"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "tX") == LUA_TNUMBER) {
            structure.tX = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"NSAffineTransform field tX is not a number"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "tY") == LUA_TNUMBER) {
            structure.tY = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"NSAffineTransform field tY is not a number"] ;
        }
        lua_pop(L, 1) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected NSAffineTransform table, found %s",
                                                  lua_typename(L, lua_type(L, idx))]] ;
    }

    [value setTransformStruct:structure] ;
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"identity",    matrix_identity},
    {"rotate",      matrix_rotate},
    {"translate",   matrix_translate},
    {"scale",       matrix_scale},
    {"shear",       matrix_shear},
    {"append",      matrix_append},
    {"prepend",     matrix_prepend},
    {"invert",      matrix_invert},

    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs_canvas_matrix_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibrary:USERDATA_TAG functions:moduleLib metaFunctions:nil] ; // or module_metaLib

    [skin registerPushNSHelper:pushNSAffineTransform         forClass:"NSAffineTransform"];
    [skin registerLuaObjectHelper:toNSAffineTransformFromLua forClass:"NSAffineTransform"
                                                     withTableMapping:"NSAffineTransform"];

    return 1;
}
