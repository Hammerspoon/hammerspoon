@import Cocoa ;
@import LuaSkin ;

static const char *USERDATA_TAG = "hs.sharing" ;
static LSRefTable  refTable = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

static id toNSURLFromLua(lua_State *L, int idx) ;

@interface HSSharingService : NSObject <NSSharingServiceDelegate>
@property NSSharingService *sharingService ;
@property int              callbackRef ;
@property int              selfRefCount ;
@end

@implementation HSSharingService

- (instancetype)initWithService:(NSString *)serviceName {
    self = [super init] ;
    if (self) {
        _sharingService = [NSSharingService sharingServiceNamed:serviceName] ;
        if (_sharingService) {
            _sharingService.delegate = self ;
            _callbackRef             = LUA_NOREF ;
            _selfRefCount            = 0 ;
        }
    }
    return self ;
}

#pragma mark * NSSharingService Delegate Methods

- (void)sharingService:(__unused NSSharingService *)sharingService didFailToShareItems:(NSArray *)items error:(NSError *)error {
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:self] ;
        [skin pushNSObject:@"didFail"] ;
        [skin pushNSObject:items withOptions:LS_NSDescribeUnknownTypes] ;
        [skin pushNSObject:error.localizedDescription] ;
        [skin protectedCallAndError:@"hs.sharing:didFail callback" nargs:4 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

- (void)sharingService:(__unused NSSharingService *)sharingService didShareItems:(NSArray *)items {
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:self] ;
        [skin pushNSObject:@"didShare"] ;
        [skin pushNSObject:items withOptions:LS_NSDescribeUnknownTypes] ;
        [skin protectedCallAndError:@"hs.sharing:didShare callback" nargs:3 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

- (void)sharingService:(__unused NSSharingService *)sharingService willShareItems:(NSArray *)items {
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:self] ;
        [skin pushNSObject:@"willShare"] ;
        [skin pushNSObject:items withOptions:LS_NSDescribeUnknownTypes] ;
        [skin protectedCallAndError:@"hs.sharing:willShare callback" nargs:3 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

@end

#pragma mark - Module Functions

/// hs.sharing.newShare(type) -> sharingObject
/// Constructor
/// Creates a new sharing object of the type specified by the identifier provided.
///
/// Parameters:
///  * type - a string specifying a sharing type identifier as listed in the [hs.sharing.builtinSharingServices](#builtinSharingServices) table or returned by the [hs.sharing.shareTypesFor](#shareTypesFor).
///
/// Returns:
///  * a sharingObject or nil if the type identifier cannot be created on this system
static int sharing_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    HSSharingService *wrapper = [[HSSharingService alloc] initWithService:[skin toNSObjectAtIndex:1]] ;
    if (wrapper && wrapper.sharingService) {
        [skin pushNSObject:wrapper] ;
    } else {
        wrapper = nil ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.sharing.shareTypesFor(items) -> identifiersTable
/// Function
/// Returns a table containing the sharing service identifiers which can share the items specified.
///
/// Parameters:
///  * items - an array (table) or list of items separated by commas which you wish to share with this module.
///
/// Returns:
///  * an array (table) containing strings which identify sharing service identifiers which may be used by the [hs.sharing.newShare](#newShare) constructor to share the specified data.
///
/// Notes:
///  * this function is intended to be used to determine the identifiers for sharing services available on your computer and that may not be included in the [hs.sharing.builtinSharingServices](#builtinSharingServices) table.
static int sharing_servicesForItems(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    NSArray *items ;
    if (lua_gettop(L) == 1) {
        items = [skin toNSObjectAtIndex:1] ;
        if (![items isKindOfClass:[NSArray class]]) {
            return luaL_argerror(L, 1, "unrecognized element in array") ;
        }
    }
    lua_newtable(L) ;
    NSArray *services = [NSSharingService sharingServicesForItems:items] ;
    if (services) {
        for (NSSharingService *aService in services) {
            NSString *label ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wselector-type-mismatch"
// this seems an obvious thing to include, but Apple in their infinite wisdom hid it, even though
// the "pretty" name returned by title can't be used with sharingServiceNamed: and this can...
            if ([aService respondsToSelector:@selector(name)]) {
                label = [aService performSelector:@selector(name)] ;
            }
#pragma clang diagnostic pop

            if (!label) label = aService.title ;
            [skin pushNSObject:label] ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    }
    return 1 ;
}

/// hs.sharing.URL(URL, [fileURL]) -> table
/// Function
/// Returns a table representing the URL specified.
///
/// Parameters:
///  * URL     - a string or table specifying the URL.
///  * fileURL - an optional boolean, default `false`, specifying whether or not the URL is supposed to represent a file on the local computer.
///
/// Returns:
///  * a table containing the necessary labels for representing the specified URL as required by the macOS APIs.
///
/// Notes:
///  * If the URL is specified as a table, it is expected to contain a `url` key with a string value specifying a proper schema and resource locator.
///
///  * Because macOS requires URLs to be represented as a specific object type which has no exact equivalent in Lua, Hammerspoon uses a table with specific keys to allow proper identification of a URL when included as an argument or result type.  Use this function or the [hs.sharing.fileURL](#fileURL) wrapper function when specifying a URL to ensure that the proper keys are defined.
///  * At present, the following keys are defined for a URL table (additional keys may be added in the future if future Hammerspoon modules require them to more completely utilize the macOS NSURL class, but these will not change):
///    * url           - a string containing the URL with a proper schema and resource locator
///    * filePath      = a string specifying the actual path to the file in case the url is a file reference URL.  Note that setting this field with this method will be silently ignored; the field is automatically inserted if appropriate when returning an NSURL object to lua.
///    * __luaSkinType - a string specifying the macOS type this table represents when converted into an Objective-C type
static int sharing_makeURL(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TTABLE, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    BOOL shouldBeFileURL = (lua_gettop(L) == 2) ? (BOOL)lua_toboolean(L, 2) : NO ;

    NSURL *theURL ;
    if (shouldBeFileURL && lua_type(L, 1) == LUA_TSTRING) {
        NSString *path = [skin toNSObjectAtIndex:1] ;
        if (!([path hasPrefix:@"file:"] || [path hasPrefix:@"FILE:"])) {
            theURL = [NSURL fileURLWithPath:[path stringByExpandingTildeInPath]] ;
        }
    }
    if (!theURL) theURL = toNSURLFromLua(L, 1) ;
    [skin pushNSObject:theURL] ;
    return 1 ;
}


#pragma mark - Module Methods

/// hs.sharing:shareItems(items) -> sharingObject
/// Method
/// Shares the items specified with the sharing service represented by the sharingObject.
///
/// Parameters:
///  * items - an array (table) or list of items separated by commas which are to be shared by the sharing service
///
/// Returns:
///  * the sharingObject, or nil if one or more of the items cannot be shared with the sharing service represented by the sharingObject.
///
/// Notes:
///  * You can check to see if all of your items can be shared with the [hs.sharing:canShareItems](#canShareItems) method.
static int sharing_performWith(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
    HSSharingService *wrapper = [skin toNSObjectAtIndex:1] ;

    NSArray *items = [skin toNSObjectAtIndex:2] ;
    if ([items isKindOfClass:[NSArray class]]) {
        if ([wrapper.sharingService canPerformWithItems:items]) {
            [wrapper.sharingService performWithItems:items] ;
            lua_pushvalue(L, 1) ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        return luaL_argerror(L, 2, "unrecognized element in array") ;
    }
    return 1 ;
}

/// hs.sharing:canShareItems(items) -> boolean
/// Method
/// Returns a boolean specifying whether or not all of the items specified can be shared with the sharing service represented by the sharingObject.
///
/// Parameters:
///  * items - an array (table) or list of items separated by commas which are to be shared by the sharing service
///
/// Returns:
///  * a boolean value indicating whether or not all of the specified items can be shared with the sharing service represented by the sharingObject.
static int sharing_canPerformWith(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
    HSSharingService *wrapper = [skin toNSObjectAtIndex:1] ;

    NSArray *items = [skin toNSObjectAtIndex:2] ;
    if ([items isKindOfClass:[NSArray class]]) {
        lua_pushboolean(L, [wrapper.sharingService canPerformWithItems:items]) ;
    } else {
        return luaL_argerror(L, 2, "unrecognized element in array") ;
    }
    return 1 ;
}

/// hs.sharing:callback(fn) -> sharingObject
/// Method
/// Set or clear the callback for the sharingObject.
///
/// Parameters:
///  * fn - A function, or nil, to set or remove the callback for the sharingObject
///
/// Returns:
///  * the sharingObject
///
/// Notes:
///  * the callback should expect 3 or 4 arguments and return no results.  The arguments will be as follows:
///    * the sharingObject itself
///    * the callback message, which will be a string equal to one of the following:
///      * "didFail"   - an error occurred while attempting to share the items
///      * "didShare"  - the sharing service has finished sharing the items
///      * "willShare" - the sharing service is about to start sharing the items; occurs before sharing actually begins
///    * an array (table) containing the items being shared; if the message is "didFail" or "didShare", the items may be in a different order or converted to a different internal type to facilitate sharing.
///    * if the message is "didFail", the fourth argument will be a localized description of the error that occurred.
static int sharing_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    HSSharingService *wrapper = [skin toNSObjectAtIndex:1] ;

    wrapper.callbackRef = [skin luaUnref:refTable ref:wrapper.callbackRef] ;
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2) ;
        wrapper.callbackRef = [skin luaRef:refTable] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.sharing:recipients([recipients]) -> current value | sharingObject
/// Method
/// Get or set the subject to be used when the sharing service performs its sharing method.
///
/// Parameters:
///  * recipients - an optional array (table) or list of recipient strings separated by commas which specify the recipients of the shared items.
///
/// Returns:
///  * if an argument is provided, returns the sharingObject; otherwise returns the current value.
///
/// Notes:
///  * not all sharing services will make use of the value set by this method.
///  * the individual recipients should be specified as strings in the format expected by the sharing service; e.g. for items being shared in an email, the recipients should be email address, etc.
static int sharing_recipients(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSSharingService *wrapper = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:wrapper.sharingService.recipients] ;
    } else {
        NSArray *recipients = [skin toNSObjectAtIndex:2] ;
        NSString __block *errorMessage ;
        if ([recipients isKindOfClass:[NSArray class]]) {
            [recipients enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if (![obj isKindOfClass:[NSString class]]) {
                    errorMessage = [NSString stringWithFormat:@"expected string at index %ld", idx + 1] ;
                    *stop = YES ;
                }
            }] ;
        } else {
            errorMessage = @"expected table of strings" ;
        }
        if (errorMessage) {
            return luaL_argerror(L, 2, errorMessage.UTF8String) ;
        } else {
            wrapper.sharingService.recipients = recipients ;
            lua_pushvalue(L, 1) ;
        }
    }
    return 1 ;
}

/// hs.sharing:subject([subject]) -> current value | sharingObject
/// Method
/// Get or set the subject to be used when the sharing service performs its sharing method.
///
/// Parameters:
///  * subject - an optional string specifying the subject for the posting of the shared content
///
/// Returns:
///  * if an argument is provided, returns the sharingObject; otherwise returns the current value.
///
/// Notes:
///  * not all sharing services will make use of the value set by this method.
static int sharing_subject(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSSharingService *wrapper = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:wrapper.sharingService.subject] ;
    } else {
        wrapper.sharingService.subject = [skin toNSObjectAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.sharing:attachments() -> table | nil
/// Method
/// If the sharing service provides an array of the attachments included when the data was posted, this method will return an array of file URL tables of the attachments.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an array (table) containing the attachment file URLs, or nil if the sharing service selected does not provide this.
///
/// Notes:
///  * not all sharing services will set a value for this property.
static int sharing_attachmentURLs(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSSharingService *wrapper = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:wrapper.sharingService.attachmentFileURLs] ;
    return 1 ;
}

/// hs.sharing:accountName() -> string | nil
/// Method
/// The account name used by the sharing service when posting on Twitter or Sina Weibo.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string containing the account name used by the sharing service, or nil if the sharing service does not provide this.
///
/// Notes:
///  * According to the Apple API documentation, only the Twitter and Sina Weibo sharing services will set this property, but this has not been fully tested.
static int sharing_accountName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSSharingService *wrapper = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:wrapper.sharingService.accountName] ;
    return 1 ;
}

/// hs.sharing:messageBody() -> string | nil
/// Method
/// If the sharing service provides the message body that was posted when sharing has completed, this method will return the message body as a string.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string containing the message body, or nil if the sharing service selected does not provide this.
///
/// Notes:
///  * not all sharing services will set a value for this property.
static int sharing_messageBody(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSSharingService *wrapper = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:wrapper.sharingService.messageBody] ;
    return 1 ;
}

/// hs.sharing:title() -> string
/// Method
/// The title for the sharing service represented by the sharingObject.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string containing the title of the sharing service.
///
/// Notes:
///  * this string differs from the identifier used to create the sharing service object with [hs.sharing.newShare](#newShare) and is intended to provide a more friendly label for the service if you need to list or refer to it elsewhere.
static int sharing_title(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSSharingService *wrapper = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:wrapper.sharingService.title] ;
    return 1 ;
}

/// hs.sharing:serviceName() -> string
/// Method
/// The service identifier for the sharing service represented by the sharingObject.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string containing the identifier for the sharing service.
///
/// Notes:
///  * this string will match the identifier used to create the sharing service object with [hs.sharing.newShare](#newShare)
static int sharing_serviceName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSSharingService *wrapper = [skin toNSObjectAtIndex:1] ;
    NSString *label ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wselector-type-mismatch"
// this seems an obvious thing to include, but Apple in their infinite wisdom hid it, even though
// the "pretty" name returned by title can't be used with sharingServiceNamed: and this can...
    if ([wrapper respondsToSelector:@selector(name)]) {
        label = [wrapper performSelector:@selector(name)] ;
    }
#pragma clang diagnostic pop
    [skin pushNSObject:label] ;
    return 1 ;
}

/// hs.sharing:permanentLink() -> URL table | nil
/// Method
/// If the sharing service provides a permanent link to the post when sharing has completed, this method will return the corresponding URL.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the URL for the permanent link, or nil if the sharing service selected does not provide this.
///
/// Notes:
///  * not all sharing services will set a value for this property.
static int sharing_permanentLink(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSSharingService *wrapper = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:wrapper.sharingService.permanentLink] ;
    return 1 ;
}

/// hs.sharing:alternateImage() -> hs.image object | nil
/// Method
/// Returns an alternate image, if one exists, representing the sharing service provided by this sharing object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an hs.image object or nil, if no alternate image representation for the sharing service is defined.
static int sharing_alternateImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSSharingService *wrapper = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:wrapper.sharingService.alternateImage] ;
    return 1 ;
}

/// hs.sharing:image() -> hs.image object | nil
/// Method
/// Returns an image, if one exists, representing the sharing service provided by this sharing object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an hs.image object or nil, if no image representation for the sharing service is defined.
static int sharing_image(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSSharingService *wrapper = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:wrapper.sharingService.image] ;
    return 1 ;
}

#pragma mark - Module Constants

static int pushBuiltinSharingServices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    lua_newtable(L) ;
    [skin pushNSObject:NSSharingServiceNameAddToAperture] ;             lua_setfield(L, -2, "addToAperture") ;
    [skin pushNSObject:NSSharingServiceNameAddToIPhoto] ;               lua_setfield(L, -2, "addToIPhoto") ;
    [skin pushNSObject:NSSharingServiceNameAddToSafariReadingList] ;    lua_setfield(L, -2, "addToSafariReadingList") ;
    [skin pushNSObject:NSSharingServiceNameComposeEmail] ;              lua_setfield(L, -2, "composeEmail") ;
    [skin pushNSObject:NSSharingServiceNameComposeMessage] ;            lua_setfield(L, -2, "composeMessage") ;
    [skin pushNSObject:NSSharingServiceNamePostImageOnFlickr] ;         lua_setfield(L, -2, "postImageOnFlickr") ;
    [skin pushNSObject:NSSharingServiceNamePostOnFacebook] ;            lua_setfield(L, -2, "postOnFacebook") ;
    [skin pushNSObject:NSSharingServiceNamePostOnLinkedIn] ;            lua_setfield(L, -2, "postOnLinkedIn") ;
    [skin pushNSObject:NSSharingServiceNamePostOnSinaWeibo] ;           lua_setfield(L, -2, "postOnSinaWeibo") ;
    [skin pushNSObject:NSSharingServiceNamePostOnTencentWeibo] ;        lua_setfield(L, -2, "postOnTencentWeibo") ;
    [skin pushNSObject:NSSharingServiceNamePostOnTwitter] ;             lua_setfield(L, -2, "postOnTwitter") ;
    [skin pushNSObject:NSSharingServiceNamePostVideoOnTudou] ;          lua_setfield(L, -2, "postVideoOnTudou") ;
    [skin pushNSObject:NSSharingServiceNamePostVideoOnVimeo] ;          lua_setfield(L, -2, "postVideoOnVimeo") ;
    [skin pushNSObject:NSSharingServiceNamePostVideoOnYouku] ;          lua_setfield(L, -2, "postVideoOnYouku") ;
    [skin pushNSObject:NSSharingServiceNameSendViaAirDrop] ;            lua_setfield(L, -2, "sendViaAirDrop") ;
    [skin pushNSObject:NSSharingServiceNameUseAsDesktopPicture] ;       lua_setfield(L, -2, "useAsDesktopPicture") ;
    [skin pushNSObject:NSSharingServiceNameUseAsFacebookProfileImage] ; lua_setfield(L, -2, "useAsFacebookProfileImage") ;
    [skin pushNSObject:NSSharingServiceNameUseAsLinkedInProfileImage] ; lua_setfield(L, -2, "useAsLinkedInProfileImage") ;
    [skin pushNSObject:NSSharingServiceNameUseAsTwitterProfileImage] ;  lua_setfield(L, -2, "useAsTwitterProfileImage") ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSSharingService(lua_State *L, id obj) {
    HSSharingService *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSSharingService *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSSharingServiceFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSSharingService *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSSharingService, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushNSURL(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSURL *url = obj ;
    lua_newtable(L) ;
    [skin pushNSObject:[url absoluteString]] ;
    lua_setfield(L, -2, "url") ;
    if (url.fileURL) {
        [skin pushNSObject:[url path]] ;
        lua_setfield(L, -2, "filePath") ;
    }
    lua_pushstring(L, "NSURL") ; lua_setfield(L, -2, "__luaSkinType") ;
    return 1 ;
}

static id toNSURLFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSURL   *url ;
    idx = lua_absindex(L, idx) ;
    if (lua_type(L, idx) == LUA_TSTRING) {
        url = [NSURL URLWithString:[skin toNSObjectAtIndex:idx]] ;
    } else if (lua_type(L, idx) == LUA_TTABLE) {
        if (lua_getfield(L, idx, "url") == LUA_TSTRING) {
            url = [NSURL URLWithString:[skin toNSObjectAtIndex:-1]] ;
        }
        lua_pop(L, 1) ;
    }
    if (!url) {
        [skin logError:[NSString stringWithFormat:@"expected string or table describing an NSURL, found %s",
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return url ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSSharingService *obj = [skin luaObjectAtIndex:1 toClass:"HSSharingService"] ;
    NSString *title = obj.sharingService.title ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSSharingService *obj1 = [skin luaObjectAtIndex:1 toClass:"HSSharingService"] ;
        HSSharingService *obj2 = [skin luaObjectAtIndex:2 toClass:"HSSharingService"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSSharingService *obj = get_objectFromUserdata(__bridge_transfer HSSharingService, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
            obj.sharingService = nil ;
            obj = nil ;
        }
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"callback",       sharing_callback},
    {"recipients",     sharing_recipients},
    {"subject",        sharing_subject},
    {"shareItems",     sharing_performWith},
    {"canShareItems",  sharing_canPerformWith},
    {"attachments",    sharing_attachmentURLs},
    {"accountName",    sharing_accountName},
    {"messageBody",    sharing_messageBody},
    {"title",          sharing_title},
    {"permanentLink",  sharing_permanentLink},
    {"alternateImage", sharing_alternateImage},
    {"image",          sharing_image},
    {"serviceName",    sharing_serviceName},

    {"__tostring",     userdata_tostring},
    {"__eq",           userdata_eq},
    {"__gc",           userdata_gc},
    {NULL,             NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"newShare",      sharing_new},
    {"shareTypesFor", sharing_servicesForItems},
    {"URL",           sharing_makeURL},
    {NULL,            NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs_libsharing(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    pushBuiltinSharingServices(L) ; lua_setfield(L, -2, "builtinSharingServices") ;

    [skin registerPushNSHelper:pushHSSharingService         forClass:"HSSharingService"];
    [skin registerLuaObjectHelper:toHSSharingServiceFromLua forClass:"HSSharingService"
                                                  withUserdataMapping:USERDATA_TAG];

    // should probably move at some point, unless this module ends up in core
    [skin registerPushNSHelper:pushNSURL                     forClass:"NSURL"] ;
    [skin registerLuaObjectHelper:toNSURLFromLua             forClass:"NSURL"
                                                     withTableMapping:"NSURL"] ;

    return 1;
}
