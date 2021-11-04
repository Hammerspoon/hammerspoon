@import Cocoa ;
@import LuaSkin ;
@import Darwin.POSIX.sys.xattr ;

/// === hs.fs.xattr ===
///
/// Get and manipulate extended attributes for files and directories
///
/// This submodule provides functions for getting and setting the extended attributes for files and directories.  Access to extended attributes is provided through the Darwin xattr functions defined in the /usr/include/sys/xattr.h header. Attribute names are expected to conform to proper UTF-8 strings and values are represented as raw data -- in Lua raw data is presented as bytes in a string object but the bytes are not required to conform to peroper UTF-8 byte code sequences. This module does not perform any encoding or decoding of the raw data.
///
/// All of the functions provided by this module can take an options table. Note that not all options are valid for all functions. The options table should be a Lua table containing an array of zero or more of the following strings:
///
///  * "noFollow"       - do not follow symbolic links; this can be used to access the attributes of the link itself.
///  * "hfsCompression" - access HFS Plus Compression extended attributes for the file or directory, if present
///  * "createOnly"     - when setting an attribute value, fail if the attribute already exists
///  * "replaceOnly"    - when setting an attribute value, fail if the attribute does not already exist
///
/// Note that the following options did not seem to be valid for the initial tests performed when developing this module and may refer the kernel level features not available to Hammerspoon; they are included here for full compatibility with the library as defined in its header. If you have more information about these options or can provide examples or documentation about their use, please submit an issue to the Hammerspoon github repository so we can provide better documentation here.
///
///  * "noSecurity"      - bypass authorization checking
///  * "noDefault"       - bypass the default extended attribute file (dot-underscore file)
///

// static const char * const USERDATA_TAG = "hs.fs.xattr" ;
static LSRefTable refTable = LUA_NOREF;

#pragma mark - Support Functions and Classes

static int parseOptionsTable(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSArray *optionList = (lua_type(L, idx) == LUA_TTABLE) ? [skin toNSObjectAtIndex:idx] : [NSArray array] ;
    if (![optionList isKindOfClass:[NSArray class]]) {
        return luaL_argerror(L, idx, "expected an array of strings") ;
    }

    __block NSString *errMsg = nil ;
    __block int      options = 0 ;
    [optionList enumerateObjectsUsingBlock:^(id obj, NSUInteger idx2, BOOL *stop) {
        if (![obj isKindOfClass:[NSString class]]) {
            errMsg = [NSString stringWithFormat:@"expected string at index %lu", (idx2 + 1)] ;
            *stop = YES ;
        } else {
            NSString *opt = (NSString *)obj ;
            if ([opt isEqualToString:@"noFollow"])            { options |= XATTR_NOFOLLOW ; }
            else if ([opt isEqualToString:@"hfsCompression"]) { options |= XATTR_SHOWCOMPRESSION ; }
            else if ([opt isEqualToString:@"createOnly"])     { options |= XATTR_CREATE ; }
            else if ([opt isEqualToString:@"replaceOnly"])    { options |= XATTR_REPLACE ; }
            else if ([opt isEqualToString:@"noSecurity"])     { options |= XATTR_NOSECURITY ; }
            else if ([opt isEqualToString:@"noDefault"])      { options |= XATTR_NODEFAULT ; }
            else {
                errMsg = [NSString stringWithFormat:@"unrecognized option %@ at index %lu", opt, (idx2 + 1)] ;
                *stop = YES ;
            }
        }
    }] ;
    if (errMsg) {
        return luaL_argerror(L, idx, errMsg.UTF8String) ;
    }
    return options ;
}

static int expandErrno(lua_State *L) {
    const char *msg = [[NSString stringWithFormat:@"unrecognized errno code %d; see /usr/include/sys/errno.h", errno] UTF8String] ;
    switch(errno) {
        case ENOTSUP:      msg = "filesystem does not support extended attributes" ; break ;
        case ERANGE:       msg = "data size out of range" ; break ;
        case EPERM:        msg = "named attribute is not permitted for this type of file or file does not support extended attributes" ; break ;
        case EISDIR:       msg = "named attribute only valid for regular file" ; break ;
        case ENOTDIR:      msg = "a path component is not a directory" ; break ;
        case ENAMETOOLONG: msg = "path, name, or a path component too long" ; break ;
        case EACCES:       msg = "permission denied" ; break ;
        case ELOOP:        msg = "too many symbolic links or links loop" ; break ;
        case EFAULT:       msg = "path points to an invalid address" ; break ;
        case EIO:          msg = "io error" ; break ;
        case EINVAL:       msg = "name is invalid or invalid option set" ; break ;
        case ENOENT:       msg = "file not found" ; break ;
        case ENOATTR:      msg = "extended attribute does not exist" ; break ;
        case EEXIST:       msg = "extended attribute already exists" ; break ;
        case EROFS:        msg = "file system mounted read-only" ; break ;
        case E2BIG:        msg = "data size of extended attribute is too large" ; break ;
    }
    return luaL_error(L, msg) ;
}

#pragma mark - Module Functions

/// hs.fs.xattr.set(path, attribute, value, [options], [position]) -> boolean
/// Function
/// Set the extended attribute to the value provided for the path specified.
///
/// Parameters:
///  * `path`      - A string specifying the path to the file or directory to set the extended attribute for
///  * `attribute` - A string specifying the name of the extended attribute to set
///  * `value`     - A string containing the value to set the extended attribute to. This value is treated as a raw sequence of bytes and does not have to conform to propert UTF-8 byte sequences.
///  * `options`   - An optional table containing options as described in this module's documentation header. Defaults to {} (an empty array).
///  * `position`  - An optional integer specifying the offset within the extended attribute. Defaults to 0. Setting this argument to a value other than 0 is only valid when `attribute` is "com.apple.ResourceFork".
///
/// Returns:
///  * True if the operation succeeds; otherwise throws a Lua error with a description of reason for failure.
static int xattr_setxattr(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TSTRING, LS_TTABLE | LS_TOPTIONAL, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;

    NSString *path = [skin toNSObjectAtIndex:1] ;
    path = path.stringByExpandingTildeInPath ;

    NSString *attribute = [skin toNSObjectAtIndex:2] ;

    NSData *value = [skin toNSObjectAtIndex:3 withOptions:LS_NSLuaStringAsDataOnly] ;

    int options = parseOptionsTable(L, 4) ;

    u_int32_t position = (lua_gettop(L) == 5) ? (u_int32_t)lua_tointeger(L, 5) : 0 ;
    if (position != 0 && ![attribute isEqualToString:@(XATTR_RESOURCEFORK_NAME)]) {
        return luaL_argerror(L, 5, [[NSString stringWithFormat:@"position argument only valid with %s attribute", XATTR_RESOURCEFORK_NAME] UTF8String]) ;
    }

    if (setxattr(path.UTF8String, attribute.UTF8String, value.bytes, value.length, position, options) < 0) {
        return expandErrno(L) ;
    } else {
        lua_pushboolean(L, YES) ;
    }
    return 1 ;
}

/// hs.fs.xattr.remove(path, attribute, [options]) -> boolean
/// Function
/// Removes the specified extended attribute from the file or directory at the path specified.
///
/// Parameters:
///  * `path`      - A string specifying the path to the file or directory to remove the extended attribute from
///  * `attribute` - A string specifying the name of the extended attribute to remove
///  * `options`   - An optional table containing options as described in this module's documentation header. Defaults to {} (an empty array).
///
/// Returns:
///  * True if the operation succeeds; otherwise throws a Lua error with a description of reason for failure.
static int xattr_removexattr(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSString *path = [skin toNSObjectAtIndex:1] ;
    path = path.stringByExpandingTildeInPath ;

    NSString *attribute = [skin toNSObjectAtIndex:2] ;

    int options = parseOptionsTable(L, 3) ;

    if (removexattr(path.UTF8String, attribute.UTF8String, options) < 0) {
        return expandErrno(L) ;
    } else {
        lua_pushboolean(L, YES) ;
    }
    return 1 ;
}

/// hs.fs.xattr.get(path, attribute, [options], [position]) -> string | true | nil
/// Function
/// Set the extended attribute to the value provided for the path specified.
///
/// Parameters:
///  * `path`      - A string specifying the path to the file or directory to get the extended attribute from
///  * `attribute` - A string specifying the name of the extended attribute to get the value of
///  * `options`   - An optional table containing options as described in this module's documentation header. Defaults to {} (an empty array).
///  * `position`  - An optional integer specifying the offset within the extended attribute. Defaults to 0. Setting this argument to a value other than 0 is only valid when `attribute` is "com.apple.ResourceFork".
///
/// Returns:
///  * If the attribute exists for the file or directory and contains data, returns the value of the attribute as a string of raw bytes which are not guaranteed to conform to proper UTF-8 byte sequences. If the attribute exist but does not have a value, returns the Lua boolean `true`.  If the attribute does not exist, returns nil. Throws a Lua error on failure with a description of the reason for the failure.
///
///  * See also [hs.fs.xattr.getHumanReadable](#getHumanReadable).
static int xattr_getxattr(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TTABLE | LS_TOPTIONAL, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;

    NSString *path = [skin toNSObjectAtIndex:1] ;
    path = path.stringByExpandingTildeInPath ;

    NSString *attribute = [skin toNSObjectAtIndex:2] ;

    int options = parseOptionsTable(L, 3) ;

    u_int32_t position = (lua_gettop(L) == 4) ? (u_int32_t)lua_tointeger(L, 4) : 0 ;
    if (position != 0 && ![attribute isEqualToString:@(XATTR_RESOURCEFORK_NAME)]) {
        return luaL_argerror(L, 4, [[NSString stringWithFormat:@"position argument only valid with %s attribute", XATTR_RESOURCEFORK_NAME] UTF8String]) ;
    }

    ssize_t bufferSize = getxattr(path.UTF8String, attribute.UTF8String, NULL, 0, position, options) ;
    if (bufferSize > 0) {
        void *buffer = malloc((size_t)bufferSize) ;
        bufferSize = getxattr(path.UTF8String, attribute.UTF8String, buffer, (size_t)bufferSize, position, options) ;
        if (bufferSize > 0) {
            [skin pushNSObject:[NSData dataWithBytes:buffer length:(size_t)bufferSize]] ;
        }
        free(buffer) ;
    } else if (bufferSize == 0) {
        lua_pushboolean(L, YES) ;
    }
    if (bufferSize < 0) {
        if (errno == ENOATTR) {
            lua_pushnil(L) ;
        } else {
            return expandErrno(L) ;
        }
    }
    return 1 ;
}

/// hs.fs.xattr.list(path, [options]) -> table
/// Function
/// Returns a list of the extended attributes currently defined for the specified file or directory
///
/// Parameters:
///  * `path`      - A string specifying the path to the file or directory to get the list of extended attributes for
///  * `options`   - An optional table containing options as described in this module's documentation header. Defaults to {} (an empty array).
///
/// Returns:
///  * a table containing an array of strings identifying the extended attributes currently defined for the file or directory; note that the order of the attributes is nondeterministic and is not guaranteed to be the same for future queries.  Throws a Lua error on failure with a description of the reason for the failure.
static int xattr_listxattr(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSString *path = [skin toNSObjectAtIndex:1] ;
    path = path.stringByExpandingTildeInPath ;

    int options = parseOptionsTable(L, 2) ;

    lua_newtable(L) ;
    ssize_t bufferSize = listxattr(path.UTF8String, NULL, 0, options) ;
    if (bufferSize > 0) {
        char *buffer = malloc(sizeof(char) * (size_t)bufferSize) ;
        bufferSize = listxattr(path.UTF8String, buffer, (size_t)bufferSize, options) ;
        if (bufferSize > 0) {
            int j = 0;
            char *p = buffer;
            while(j < bufferSize) {
                lua_pushstring(L, p) ;
                size_t t = lua_rawlen(L, -1) + 1 ;
                p += t ;
                j += t ;
                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
        }
        free(buffer) ;
    }
    if (bufferSize < 0) {
        lua_pop(L, 1) ;
        return expandErrno(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

#pragma mark - Module Constants

// #define	XATTR_MAXNAMELEN   127
//
// /* See the ATTR_CMN_FNDRINFO section of getattrlist(2) for details on FinderInfo */
// #define	XATTR_FINDERINFO_NAME	  "com.apple.FinderInfo"

#pragma mark - Lua<->NSObject Conversion Functions

#pragma mark - Hammerspoon/Lua Infrastructure

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"list",   xattr_listxattr},
    {"get",    xattr_getxattr},
    {"set",    xattr_setxattr},
    {"remove", xattr_removexattr},
    {NULL,     NULL}
};

int luaopen_hs_libfsxattr(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibrary:"hs.fs.xattr" functions:moduleLib metaFunctions:nil] ;

    return 1;
}
