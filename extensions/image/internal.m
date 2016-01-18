//#import <Appkit/NSImage.h>
#import <LuaSkin/LuaSkin.h>
#import "ASCIImage/PARImage+ASCIIInput.h"

#define USERDATA_TAG "hs.image"

/// hs.image.systemImageNames[]
/// Constant
/// Array containing the names of internal system images for use with hs.drawing.image
///
/// Notes:
///  * Image names pulled from NSImage.h
///  * This table has a __tostring() metamethod which allows listing it's contents in the Hammerspoon console by typing `hs.image.systemImageNames`.
static int pushNSImageNameTable(lua_State *L) {
    lua_newtable(L) ;
        lua_pushstring(L, [NSImageNameQuickLookTemplate UTF8String]) ;                lua_setfield(L, -2, "QuickLookTemplate") ;
        lua_pushstring(L, [NSImageNameBluetoothTemplate UTF8String]) ;                lua_setfield(L, -2, "BluetoothTemplate") ;
        lua_pushstring(L, [NSImageNameIChatTheaterTemplate UTF8String]) ;             lua_setfield(L, -2, "IChatTheaterTemplate") ;
        lua_pushstring(L, [NSImageNameSlideshowTemplate UTF8String]) ;                lua_setfield(L, -2, "SlideshowTemplate") ;
        lua_pushstring(L, [NSImageNameActionTemplate UTF8String]) ;                   lua_setfield(L, -2, "ActionTemplate") ;
        lua_pushstring(L, [NSImageNameSmartBadgeTemplate UTF8String]) ;               lua_setfield(L, -2, "SmartBadgeTemplate") ;
        lua_pushstring(L, [NSImageNameIconViewTemplate UTF8String]) ;                 lua_setfield(L, -2, "IconViewTemplate") ;
        lua_pushstring(L, [NSImageNameListViewTemplate UTF8String]) ;                 lua_setfield(L, -2, "ListViewTemplate") ;
        lua_pushstring(L, [NSImageNameColumnViewTemplate UTF8String]) ;               lua_setfield(L, -2, "ColumnViewTemplate") ;
        lua_pushstring(L, [NSImageNameFlowViewTemplate UTF8String]) ;                 lua_setfield(L, -2, "FlowViewTemplate") ;
        lua_pushstring(L, [NSImageNamePathTemplate UTF8String]) ;                     lua_setfield(L, -2, "PathTemplate") ;
        lua_pushstring(L, [NSImageNameInvalidDataFreestandingTemplate UTF8String]) ;  lua_setfield(L, -2, "InvalidDataFreestandingTemplate") ;
        lua_pushstring(L, [NSImageNameLockLockedTemplate UTF8String]) ;               lua_setfield(L, -2, "LockLockedTemplate") ;
        lua_pushstring(L, [NSImageNameLockUnlockedTemplate UTF8String]) ;             lua_setfield(L, -2, "LockUnlockedTemplate") ;
        lua_pushstring(L, [NSImageNameGoRightTemplate UTF8String]) ;                  lua_setfield(L, -2, "GoRightTemplate") ;
        lua_pushstring(L, [NSImageNameGoLeftTemplate UTF8String]) ;                   lua_setfield(L, -2, "GoLeftTemplate") ;
        lua_pushstring(L, [NSImageNameRightFacingTriangleTemplate UTF8String]) ;      lua_setfield(L, -2, "RightFacingTriangleTemplate") ;
        lua_pushstring(L, [NSImageNameLeftFacingTriangleTemplate UTF8String]) ;       lua_setfield(L, -2, "LeftFacingTriangleTemplate") ;
        lua_pushstring(L, [NSImageNameAddTemplate UTF8String]) ;                      lua_setfield(L, -2, "AddTemplate") ;
        lua_pushstring(L, [NSImageNameRemoveTemplate UTF8String]) ;                   lua_setfield(L, -2, "RemoveTemplate") ;
        lua_pushstring(L, [NSImageNameRevealFreestandingTemplate UTF8String]) ;       lua_setfield(L, -2, "RevealFreestandingTemplate") ;
        lua_pushstring(L, [NSImageNameFollowLinkFreestandingTemplate UTF8String]) ;   lua_setfield(L, -2, "FollowLinkFreestandingTemplate") ;
        lua_pushstring(L, [NSImageNameEnterFullScreenTemplate UTF8String]) ;          lua_setfield(L, -2, "EnterFullScreenTemplate") ;
        lua_pushstring(L, [NSImageNameExitFullScreenTemplate UTF8String]) ;           lua_setfield(L, -2, "ExitFullScreenTemplate") ;
        lua_pushstring(L, [NSImageNameStopProgressTemplate UTF8String]) ;             lua_setfield(L, -2, "StopProgressTemplate") ;
        lua_pushstring(L, [NSImageNameStopProgressFreestandingTemplate UTF8String]) ; lua_setfield(L, -2, "StopProgressFreestandingTemplate") ;
        lua_pushstring(L, [NSImageNameRefreshTemplate UTF8String]) ;                  lua_setfield(L, -2, "RefreshTemplate") ;
        lua_pushstring(L, [NSImageNameRefreshFreestandingTemplate UTF8String]) ;      lua_setfield(L, -2, "RefreshFreestandingTemplate") ;
        lua_pushstring(L, [NSImageNameBonjour UTF8String]) ;                          lua_setfield(L, -2, "Bonjour") ;
        lua_pushstring(L, [NSImageNameComputer UTF8String]) ;                         lua_setfield(L, -2, "Computer") ;
        lua_pushstring(L, [NSImageNameFolderBurnable UTF8String]) ;                   lua_setfield(L, -2, "FolderBurnable") ;
        lua_pushstring(L, [NSImageNameFolderSmart UTF8String]) ;                      lua_setfield(L, -2, "FolderSmart") ;
        lua_pushstring(L, [NSImageNameFolder UTF8String]) ;                           lua_setfield(L, -2, "Folder") ;
        lua_pushstring(L, [NSImageNameNetwork UTF8String]) ;                          lua_setfield(L, -2, "Network") ;
        lua_pushstring(L, [NSImageNameMobileMe UTF8String]) ;                         lua_setfield(L, -2, "MobileMe") ;
        lua_pushstring(L, [NSImageNameMultipleDocuments UTF8String]) ;                lua_setfield(L, -2, "MultipleDocuments") ;
        lua_pushstring(L, [NSImageNameUserAccounts UTF8String]) ;                     lua_setfield(L, -2, "UserAccounts") ;
        lua_pushstring(L, [NSImageNamePreferencesGeneral UTF8String]) ;               lua_setfield(L, -2, "PreferencesGeneral") ;
        lua_pushstring(L, [NSImageNameAdvanced UTF8String]) ;                         lua_setfield(L, -2, "Advanced") ;
        lua_pushstring(L, [NSImageNameInfo UTF8String]) ;                             lua_setfield(L, -2, "Info") ;
        lua_pushstring(L, [NSImageNameFontPanel UTF8String]) ;                        lua_setfield(L, -2, "FontPanel") ;
        lua_pushstring(L, [NSImageNameColorPanel UTF8String]) ;                       lua_setfield(L, -2, "ColorPanel") ;
        lua_pushstring(L, [NSImageNameUser UTF8String]) ;                             lua_setfield(L, -2, "User") ;
        lua_pushstring(L, [NSImageNameUserGroup UTF8String]) ;                        lua_setfield(L, -2, "UserGroup") ;
        lua_pushstring(L, [NSImageNameEveryone UTF8String]) ;                         lua_setfield(L, -2, "Everyone") ;
        lua_pushstring(L, [NSImageNameUserGuest UTF8String]) ;                        lua_setfield(L, -2, "UserGuest") ;
        lua_pushstring(L, [NSImageNameMenuOnStateTemplate UTF8String]) ;              lua_setfield(L, -2, "MenuOnStateTemplate") ;
        lua_pushstring(L, [NSImageNameMenuMixedStateTemplate UTF8String]) ;           lua_setfield(L, -2, "MenuMixedStateTemplate") ;
        lua_pushstring(L, [NSImageNameApplicationIcon UTF8String]) ;                  lua_setfield(L, -2, "ApplicationIcon") ;
        lua_pushstring(L, [NSImageNameTrashEmpty UTF8String]) ;                       lua_setfield(L, -2, "TrashEmpty") ;
        lua_pushstring(L, [NSImageNameTrashFull UTF8String]) ;                        lua_setfield(L, -2, "TrashFull") ;
        lua_pushstring(L, [NSImageNameHomeTemplate UTF8String]) ;                     lua_setfield(L, -2, "HomeTemplate") ;
        lua_pushstring(L, [NSImageNameBookmarksTemplate UTF8String]) ;                lua_setfield(L, -2, "BookmarksTemplate") ;
        lua_pushstring(L, [NSImageNameCaution UTF8String]) ;                          lua_setfield(L, -2, "Caution") ;
        lua_pushstring(L, [NSImageNameStatusAvailable UTF8String]) ;                  lua_setfield(L, -2, "StatusAvailable") ;
        lua_pushstring(L, [NSImageNameStatusPartiallyAvailable UTF8String]) ;         lua_setfield(L, -2, "StatusPartiallyAvailable") ;
        lua_pushstring(L, [NSImageNameStatusUnavailable UTF8String]) ;                lua_setfield(L, -2, "StatusUnavailable") ;
        lua_pushstring(L, [NSImageNameStatusNone UTF8String]) ;                       lua_setfield(L, -2, "StatusNone") ;
        lua_pushstring(L, [NSImageNameShareTemplate UTF8String]) ;                    lua_setfield(L, -2, "ShareTemplate") ;
    return 1;
}

/// hs.image.imageFromPath(path) -> object
/// Constructor
/// Loads an image file
///
/// Parameters:
///  * path - A string containing the path to an image file on disk
///
/// Returns:
///  * An `hs.image` object, or nil if an error occured
static int imageFromPath(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];

    NSString* imagePath = [skin toNSObjectAtIndex:1];
    imagePath = [imagePath stringByExpandingTildeInPath];
    imagePath = [[imagePath componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@""];
    NSImage *newImage = [[NSImage alloc] initByReferencingFile:imagePath];

    if (newImage && newImage.valid) {
        [[LuaSkin shared] pushNSObject:newImage];
    } else {
        return luaL_error(L, "Unable to load image: %s", [imagePath UTF8String]);
    }

    return 1;
}

/// hs.image.imageFromASCII(ascii[, context]) -> object
/// Constructor
/// Creates an image from an ASCII representation with the specified context.
///
/// Parameters:
///  * ascii - A string containing a representation of an image
///  * context - An optional table containing the context for each shape in the image.  A shape is considered a single drawing element (point, ellipse, line, or polygon) as defined at https://github.com/cparnot/ASCIImage and http://cocoamine.net/blog/2015/03/20/replacing-photoshop-with-nsstring/.
///    * The context table is an optional (possibly sparse) array in which the index represents the order in which the shapes are defined.  The last (highest) numbered index in the sparse array specifies the default settings for any unspecified index and any settings which are not explicitly set in any other given index.
///    * Each index consists of a table which can contain one or more of the following keys:
///      * fillColor - the color with which the shape will be filled (defaults to black)  Color is defined in a table containing color component values between 0.0 and 1.0 for each of the keys:
///        * red (default 0.0)
///        * green (default 0.0)
///        * blue (default 0.0)
///        * alpha (default 1.0)
///      * strokeColor - the color with which the shape will be stroked (defaults to black)
///      * lineWidth - the line width (number) for the stroke of the shape (defaults to 1 if anti-aliasing is on or (√2)/2 if it is off -- approximately 0.7)
///      * shouldClose - a boolean indicating whether or not the shape should be closed (defaults to true)
///      * antialias - a boolean indicating whether or not the shape should be antialiased (defaults to true)
///
/// Returns:
///  * An `hs.image` object, or nil if an error occured
///
/// Notes:
///  * To use the ASCII diagram image support, see https://github.com/cparnot/ASCIImage and http://cocoamine.net/blog/2015/03/20/replacing-photoshop-with-nsstring/
///  * The default for lineWidth, when antialiasing is off, is defined within the ASCIImage library. Geometrically it represents one half of the hypotenuse of the unit right-triangle and is a more accurate representation of a "real" point size when dealing with arbitrary angles and lines than 1.0 would be.
static int imageWithContextFromASCII(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK];
    NSString *imageASCII = [skin toNSObjectAtIndex:1];

    if ([imageASCII hasPrefix:@"ASCII:"]) { imageASCII = [imageASCII substringFromIndex: 6]; }
    imageASCII = [imageASCII stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSArray *rep = [imageASCII componentsSeparatedByString:@"\n"];

    NSColor *defaultFillColor   = [NSColor blackColor] ;
    NSColor *defaultStrokeColor = [NSColor blackColor] ;
    BOOL     defaultAntiAlias   = YES ;
    BOOL     defaultShouldClose = YES ;
    CGFloat  defaultLineWidth   = NAN ;

    NSMutableDictionary *contextTable = [[NSMutableDictionary alloc] init] ;
    lua_Integer          maxIndex     = 0 ;

    // build context from table

    switch (lua_type(L, 2)) {
        case LUA_TTABLE:
            maxIndex = [skin maxNatIndex:2] ;
// NSLog(@"maxIndex = %d", maxIndex) ;
            if (maxIndex == 0) break ;

            lua_pushnil(L);  /* first key */
            while (lua_next(L, 2) != 0) { // 'key' (at index -2) and 'value' (at index -1)
                if (lua_istable(L, -1) && lua_isinteger(L, -2)) {
                    NSMutableDictionary *thisEntry = [[NSMutableDictionary alloc] init] ;

                    if (lua_getfield(L, -1, "fillColor") == LUA_TTABLE)
                        [thisEntry setObject:[skin luaObjectAtIndex:-1 toClass:"NSColor"] forKey:@"fillColor"];
                    lua_pop(L, 1);

                    if (lua_getfield(L, -1, "strokeColor") == LUA_TTABLE)
                        [thisEntry setObject:[skin luaObjectAtIndex:-1 toClass:"NSColor"] forKey:@"strokeColor"];
                    lua_pop(L, 1);

                    if (lua_getfield(L, -1, "lineWidth") == LUA_TNUMBER)
                        [thisEntry setObject:@(lua_tonumber(L, -1)) forKey:@"lineWidth"];
                    lua_pop(L, 1);

                    if (lua_getfield(L, -1, "shouldClose") == LUA_TBOOLEAN)
                        [thisEntry setObject:@(lua_toboolean(L, -1)) forKey:@"shouldClose"];
                    lua_pop(L, 1);

                    if (lua_getfield(L, -1, "antialias") == LUA_TBOOLEAN)
                        [thisEntry setObject:@(lua_toboolean(L, -1)) forKey:@"antialias"];
                    lua_pop(L, 1);

                    if ([thisEntry count] > 0)
                        [contextTable setObject:thisEntry forKey:@(lua_tointeger(L, -2))];
                }
                lua_pop(L, 1);  // removes 'value'; keeps 'key' for next iteration
            }

            if ([contextTable count] == 0) {
                maxIndex = 0 ;
                break ;
            }

            if ([contextTable objectForKey:@(maxIndex)]) {
                if ([[contextTable objectForKey:@(maxIndex)] objectForKey:@"fillColor"])
                    defaultFillColor = [[contextTable objectForKey:@(maxIndex)] objectForKey:@"fillColor"] ;
                if ([[contextTable objectForKey:@(maxIndex)] objectForKey:@"strokeColor"])
                    defaultStrokeColor = [[contextTable objectForKey:@(maxIndex)] objectForKey:@"strokeColor"] ;
                if ([[contextTable objectForKey:@(maxIndex)] objectForKey:@"antialias"])
                    defaultAntiAlias = [[[contextTable objectForKey:@(maxIndex)] objectForKey:@"antialias"] boolValue] ;
                if ([[contextTable objectForKey:@(maxIndex)] objectForKey:@"shouldClose"])
                    defaultShouldClose = [[[contextTable objectForKey:@(maxIndex)] objectForKey:@"shouldClose"] boolValue] ;
                if ([[contextTable objectForKey:@(maxIndex)] objectForKey:@"lineWidth"])
                    defaultLineWidth = [[[contextTable objectForKey:@(maxIndex)] objectForKey:@"lineWidth"] floatValue] ;
            }
            break;
        case LUA_TNIL:
        case LUA_TNONE:
            break;
        default:
            return luaL_error(L, "Unexpected type passed to hs.image.imageWithContextFromASCII as the context table: %s", lua_typename(L, lua_type(L, 2))) ;
    }

    if (isnan(defaultLineWidth)) { defaultLineWidth = defaultAntiAlias ? 1.0 : sqrtf(2.0)/2.0; }

// NSLog(@"contextTable: %@", contextTable) ;

    NSImage *newImage = [NSImage imageWithASCIIRepresentation:rep
                                               contextHandler:^(NSMutableDictionary *context) {
              NSInteger index = [context[ASCIIContextShapeIndex] integerValue];
              context[ASCIIContextFillColor]       = defaultFillColor ;
              context[ASCIIContextStrokeColor]     = defaultStrokeColor ;
              context[ASCIIContextLineWidth]       = @(defaultLineWidth) ;
              context[ASCIIContextShouldClose]     = @(defaultShouldClose) ;
              context[ASCIIContextShouldAntialias] = @(defaultAntiAlias) ;
// NSLog(@"Checking Shape #: %ld", index) ;
              if ((index + 1) <= maxIndex) {
                  if ([contextTable objectForKey:@(index + 1)]) {
                      if ([[contextTable objectForKey:@(index + 1)] objectForKey:@"fillColor"])
                          context[ASCIIContextFillColor] = [[contextTable objectForKey:@(index + 1)] objectForKey:@"fillColor"] ;
                      if ([[contextTable objectForKey:@(index + 1)] objectForKey:@"strokeColor"])
                          context[ASCIIContextStrokeColor] = [[contextTable objectForKey:@(index + 1)] objectForKey:@"strokeColor"] ;
                      if ([[contextTable objectForKey:@(index + 1)] objectForKey:@"antialias"])
                          context[ASCIIContextShouldAntialias] = [[contextTable objectForKey:@(index + 1)] objectForKey:@"antialias"] ;
                      if ([[contextTable objectForKey:@(index + 1)] objectForKey:@"shouldClose"])
                          context[ASCIIContextShouldClose] = [[contextTable objectForKey:@(index + 1)] objectForKey:@"shouldClose"] ;
                      if ([[contextTable objectForKey:@(index + 1)] objectForKey:@"lineWidth"])
                          context[ASCIIContextLineWidth] = [[contextTable objectForKey:@(index + 1)] objectForKey:@"lineWidth"] ;
                  }
              }
// NSLog(@"specificContext = %@", context) ;
          }] ;

    if (newImage) {
        [skin pushNSObject:newImage];
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.image.imageFromName(string) -> object
/// Constructor
/// Returns the hs.image object for the specified name, if it exists.
///
/// Parameters:
///  * Name - the name of the image to return.
///
/// Returns:
///  * An hs.image object or nil, if no image was found with the specified name.
///
/// Notes:
///  * Some predefined labels corresponding to OS X System default images can be found in `hs.image.systemImageNames`.
///  * Names are not required to be unique: The search order is as follows, and the first match found is returned:
///     * an image whose name was explicitly set with the `setName` method since the last full restart of Hammerspoon
///     * Hammerspoon's main application bundle
///     * the Application Kit framework (this is where most of the images listed in `hs.image.systemImageNames` are located)
///  * Image names can be assigned by the image creator or by calling the `hs.image:setName` method on an hs.image object.
static int imageFromName(lua_State *L) {
    const char* imageName = luaL_checkstring(L, 1) ;

    NSImage *newImage = [NSImage imageNamed:[NSString stringWithUTF8String:imageName]] ;
    if (newImage) {
        [[LuaSkin shared] pushNSObject:newImage] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.image.imageFromAppBundle(bundleID) -> object
/// Constructor
/// Creates an `hs.image` object using the icon from an App
///
/// Parameters:
///  * bundleID - A string containing the bundle identifier of an application
///
/// Returns:
///  * An `hs.image` object or nil, if no app icon was found
static int imageFromApp(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];
    NSString *imagePath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:[skin toNSObjectAtIndex:1]];
    NSImage *iconImage = [[NSWorkspace sharedWorkspace] iconForFile:imagePath];

    if (iconImage) {
        [[LuaSkin shared] pushNSObject:iconImage];
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/// hs.image:getImageName() -> string
/// Method
/// Returns the name assigned to the hs.image object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * Name - the name assigned to the hs.image object.
static int getImageName(lua_State* L) {
    NSImage *testImage = [[LuaSkin shared] luaObjectAtIndex:1 toClass:"NSImage"] ;
    lua_pushstring(L, [[testImage name] UTF8String]) ;
    return 1 ;
}

/// hs.image:setImageName(Name) -> boolean
/// Method
/// Assigns the name assigned to the hs.image object.
///
/// Parameters:
///  * Name - the name to assign to the hs.image object.
///
/// Returns:
///  * Status - a boolean value indicating success (true) or failure (false) when assigning the specified name.
static int setImageName(lua_State* L) {
    NSImage *testImage = [[LuaSkin shared] luaObjectAtIndex:1 toClass:"NSImage"] ;
    if (lua_isnil(L,2))
        lua_pushboolean(L, [testImage setName:nil]) ;
    else
        lua_pushboolean(L, [testImage setName:[NSString stringWithUTF8String:luaL_checkstring(L, 2)]]) ;
    return 1 ;
}

static int userdata_tostring(lua_State* L) {
    NSImage *testImage = [[LuaSkin shared] luaObjectAtIndex:1 toClass:"NSImage"] ;
    NSString* theName = [testImage name] ;

    if (!theName) theName = @"" ; // unlike some cases, [NSImage name] apparently returns an actual NULL instead of an empty string...

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, theName, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
    NSImage *image1 = [[LuaSkin shared] luaObjectAtIndex:1 toClass:"NSImage"] ;
    NSImage *image2 = [[LuaSkin shared] luaObjectAtIndex:2 toClass:"NSImage"] ;

    return image1 == image2 ;
}

/// hs.image:saveToFile(filename[, filetype]) -> boolean
/// Method
/// Save the hs.image object as an image of type `filetype` to the specified filename.
///
/// Parameters:
///  * filename - the path and name of the file to save.
///  * filetype - optional case-insensitive string paramater specifying the file type to save (default PNG)
///    * PNG  - save in Portable Network Graphics (PNG) format
///    * TIFF - save in Tagged Image File Format (TIFF) format
///    * BMP  - save in Windows bitmap image (BMP) format
///    * GIF  - save in Graphics Image Format (GIF) format
///    * JPEG - save in Joint Photographic Experts Group (JPEG) format
///
/// Returns:
///  * Status - a boolean value indicating success (true) or failure (false)
///
/// Notes:
///  * Saves image at its original size.
static int saveToFile(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK];
    NSImage*  theImage = [skin luaObjectAtIndex:1 toClass:"NSImage"] ;
    NSString* filePath = [skin toNSObjectAtIndex:2] ;
    NSBitmapImageFileType fileType = NSPNGFileType ;

    if (lua_isstring(L, 3)) {
        NSString* typeLabel = [skin toNSObjectAtIndex:3] ;
        if      ([typeLabel compare:@"PNG"  options:NSCaseInsensitiveSearch] == NSOrderedSame) { fileType = NSPNGFileType  ; }
        else if ([typeLabel compare:@"TIFF" options:NSCaseInsensitiveSearch] == NSOrderedSame) { fileType = NSTIFFFileType ; }
        else if ([typeLabel compare:@"BMP"  options:NSCaseInsensitiveSearch] == NSOrderedSame) { fileType = NSBMPFileType  ; }
        else if ([typeLabel compare:@"GIF"  options:NSCaseInsensitiveSearch] == NSOrderedSame) { fileType = NSGIFFileType  ; }
        else if ([typeLabel compare:@"JPEG" options:NSCaseInsensitiveSearch] == NSOrderedSame) { fileType = NSJPEGFileType ; }
        else if ([typeLabel compare:@"JPG"  options:NSCaseInsensitiveSearch] == NSOrderedSame) { fileType = NSJPEGFileType ; }
        else {
            return luaL_error(L, "hs.image:saveToFile:: invalid file type specified") ;
        }
    }

    BOOL result = false;

    NSData *tiffRep = [theImage TIFFRepresentation];
    if (!tiffRep)  return luaL_error(L, "Unable to write image file: Can't create internal representation");

    NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:tiffRep];
    if (!rep)  return luaL_error(L, "Unable to write image file: Can't wrap internal representation");

    NSData* fileData = [rep representationUsingType:fileType properties:@{}];
    if (!fileData) return luaL_error(L, "Unable to write image file: Can't convert internal representation");

    NSError *error;
    if ([fileData writeToFile:[filePath stringByExpandingTildeInPath] options:NSDataWritingAtomic error:&error])
        result = YES ;
    else
        return luaL_error(L, "Unable to write image file: %s", [[error localizedDescription] UTF8String]);

    lua_pushboolean(L, result) ;
    return 1 ;
}

static int userdata_gc(lua_State* L) {
// Get the NSImage so ARC can release it...
    void **thingy = luaL_checkudata(L, 1, USERDATA_TAG) ;
    NSImage* image = (__bridge_transfer NSImage *) *thingy ;
    [image setName:nil] ; // remove from image cache
    [image recache] ;     // invalidate image rep caches
    image = nil;
    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     [hsimageReferences removeAllIndexes];
//     hsimageReferences = nil;
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"name",       getImageName},
    {"setName",    setImageName},
    {"saveToFile", saveToFile},
    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"imageFromPath",             imageFromPath},
    {"imageFromASCII",            imageWithContextFromASCII},
//     {"imageWithContextFromASCII", imageWithContextFromASCII},
    {"imageFromName",             imageFromName},
    {"imageFromAppBundle",        imageFromApp},
    {NULL,                        NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc",                meta_gc},
//     {NULL,                  NULL}
// };

// [[LuaSkin shared] pushNSObject:NSImage]
// C-API
// Pushes the provided NSImage onto the Lua Stack as a hs.image userdata object
static int NSImage_tolua(lua_State *L, id obj) {
    NSImage *theImage = obj ;
    theImage.cacheMode = NSImageCacheNever ;
    void** imagePtr = lua_newuserdata(L, sizeof(NSImage *));
    *imagePtr = (__bridge_retained void *)theImage;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1 ;
}

static id HSImage_toNSImage(lua_State *L, int idx) {
    void *ptr = luaL_testudata(L, idx, USERDATA_TAG) ;
    if (ptr) {
        return (__bridge NSImage *)*((void **)ptr) ;
    } else {
        return nil ;
    }
}


int luaopen_hs_image_internal(lua_State* L) {
    [[LuaSkin shared] registerLibraryWithObject:USERDATA_TAG
                                      functions:moduleLib
                                  metaFunctions:nil
                                objectFunctions:userdata_metaLib];

    pushNSImageNameTable(L); lua_setfield(L, -2, "systemImageNames") ;

    [[LuaSkin shared] registerPushNSHelper:NSImage_tolua        forClass:"NSImage"] ;
    [[LuaSkin shared] registerLuaObjectHelper:HSImage_toNSImage forClass:"NSImage" withUserdataMapping:USERDATA_TAG] ;
    return 1;
}
