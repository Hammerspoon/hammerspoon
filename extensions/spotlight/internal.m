@import Cocoa ;
@import LuaSkin ;

static const char       *USERDATA_TAG = "hs.spotlight" ;
static const char       *ITEM_UD_TAG  = "hs.spotlight.item" ;
static const char       *GROUP_UD_TAG = "hs.spotlight.group" ;

static LSRefTable        refTable = LUA_NOREF;
static NSOperationQueue *moduleSearchQueue ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

static id toNSSortDescriptorFromLua(lua_State *L, int idx) ;

@interface HSMetadataQuery : NSObject
@property NSMetadataQuery *metadataSearch ;
@property int             callbackRef ;
@property int             selfPushCount ;
@property BOOL            wantComplete ;
@property BOOL            wantProgress ;
@property BOOL            wantStart ;
@property BOOL            wantUpdate ;
@end

@implementation HSMetadataQuery

- (instancetype)init {
    self = [super init] ;
    if (self) {
        _callbackRef    = LUA_NOREF ;
        _selfPushCount  = 0 ;
        _metadataSearch = [[NSMetadataQuery alloc] init] ;
        _wantComplete   = YES ;
        _wantProgress   = NO ;
        _wantStart      = NO ;
        _wantUpdate     = NO ;

        if (!moduleSearchQueue) moduleSearchQueue = [NSOperationQueue new] ;
        _metadataSearch.operationQueue = moduleSearchQueue ;

        // Register the notifications for batch and completion updates
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter] ;
        [notificationCenter addObserver:self selector:@selector(queryDidFinish:)
                                                 name:NSMetadataQueryDidFinishGatheringNotification
                                               object:_metadataSearch];
        [notificationCenter addObserver:self selector:@selector(queryDidStart:)
                                                 name:NSMetadataQueryDidStartGatheringNotification
                                               object:_metadataSearch];
        [notificationCenter addObserver:self selector:@selector(queryDidUpdate:)
                                                 name:NSMetadataQueryDidUpdateNotification
                                               object:_metadataSearch];
        [notificationCenter addObserver:self selector:@selector(queryProgress:)
                                                 name:NSMetadataQueryGatheringProgressNotification
                                               object:_metadataSearch];
    }
    return self ;
}

- (void)queryDidFinish:(NSNotification *)notification {
    if (_callbackRef != LUA_NOREF && _wantComplete) [self doCallbackFor:@"didFinish" with:notification] ;
}

- (void)queryDidStart:(NSNotification *)notification {
    if (_callbackRef != LUA_NOREF && _wantStart) [self doCallbackFor:@"didStart" with:notification] ;
}

- (void)queryDidUpdate:(NSNotification *)notification {
    if (_callbackRef != LUA_NOREF && _wantUpdate) [self doCallbackFor:@"didUpdate" with:notification] ;
}

- (void)queryProgress:(NSNotification *)notification {
    if (_callbackRef != LUA_NOREF && _wantProgress) [self doCallbackFor:@"inProgress" with:notification] ;
}

- (void)doCallbackFor:(NSString *)message with:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_callbackRef != LUA_NOREF) {
            LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
            _lua_stackguard_entry(skin.L);
            [skin pushLuaRef:refTable ref:self->_callbackRef] ;
            [skin pushNSObject:self] ;
            [skin pushNSObject:message] ;
            [skin pushNSObject:notification.userInfo withOptions:LS_NSDescribeUnknownTypes] ;
            [skin protectedCallAndError:@"hs.spotlight" nargs:3 nresults:0];
            _lua_stackguard_exit(skin.L);
        }
    }) ;
}

@end

#pragma mark - Module Functions

/// hs.spotlight.new() -> spotlightObject
/// Constructor
/// Creates a new spotlightObject to use for Spotlight searches.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a new spotlightObject
static int spotlight_new(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    [skin pushNSObject:[[HSMetadataQuery alloc] init]] ;
    return 1 ;
}

/// hs.spotlight.newWithin(spotlightObject) -> spotlightObject
/// Constructor
/// Creates a new spotlightObject that limits its searches to the current results of another spotlightObject.
///
/// Parameters:
///  * `spotlightObject` - the object whose current results are to be used to limit the scope of the new Spotlight search.
///
/// Returns:
///  * a new spotlightObject
static int spotlight_searchWithin(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    HSMetadataQuery *newQuery = [[HSMetadataQuery alloc] init] ;
    if (newQuery) {
        [query.metadataSearch disableUpdates] ;
        newQuery.metadataSearch.searchItems = query.metadataSearch.results ;
        [query.metadataSearch enableUpdates] ;
    }

    [skin pushNSObject:newQuery] ;
    return 1 ;
}


#pragma mark - Module Methods

// wrapped in init.lua
static int spotlight_searchScopes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:query.metadataSearch.searchScopes] ;
    } else {
        NSMutableArray *newScopes = [[NSMutableArray alloc] init] ;
        NSString __block *errorMessage ;
        NSArray *items = [skin toNSObjectAtIndex:2] ;
        if (items) {
            if (![items isKindOfClass:[NSArray class]]) items = [NSArray arrayWithObject:items] ;
            [items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([obj isKindOfClass:[NSString class]]) {
                    [newScopes addObject:[(NSString *)obj stringByExpandingTildeInPath]] ;
                } else if ([obj isKindOfClass:[NSURL class]]) {
                // Handle automatic translation when table includes __luaSkinType="NSURL"
                    if (![(NSURL *)obj isFileURL]) {
                        errorMessage = [NSString stringWithFormat:@"index %lu does not represent a file URL", idx + 1] ;
                        *stop = YES ;
                    } else {
                        [newScopes addObject:obj] ;
                    }
                } else if ([obj isKindOfClass:[NSDictionary class]]) {
                // and handle conversion when table doesn't include __luaSkinType="NSURL"
                    NSString *stringAsURL = [(NSDictionary *)obj objectForKey:@"url"] ;
                    if (stringAsURL) {
                        NSURL *newURL = [NSURL URLWithString:stringAsURL] ;
                        if (!newURL.fileURL) {
                            errorMessage = [NSString stringWithFormat:@"index %lu does not represent a file URL", idx + 1] ;
                            *stop = YES ;
                        } else {
                            [newScopes addObject:newURL] ;
                        }
                    } else {
                        errorMessage = [NSString stringWithFormat:@"index %lu does not represent a file URL", idx + 1] ;
                        *stop = YES ;
                    }
                } else {
                    errorMessage = [NSString stringWithFormat:@"index %lu is not a path string or a file URL", idx + 1] ;
                    *stop = YES ;
                }
            }] ;
        } else {
            errorMessage = @"unexpected type conversion error" ;
        }
        if (errorMessage) {
            return luaL_argerror(L, 2, errorMessage.UTF8String) ;
        } else {
            query.metadataSearch.searchScopes = newScopes ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.spotlight:setCallback(fn) -> spotlightObject
/// Method
/// Set or remove the callback function for the Spotlight search object.
///
/// Parameters:
///  * `fn` - the function to replace the current callback function.  If this argument is an explicit nil, removes the current callback function and does not replace it.  The function should expect 2 or 3 arguments and should return none.
///
/// Returns:
///  * the spotlightObject
///
/// Notes:
///  * Depending upon the messages set with the [hs.spotlight:callbackMessages](#callbackMessages) method, the following callbacks may occur:
///
///    * obj, "didStart" -- occurs when the initial gathering phase of a Spotlight search begins.
///      * `obj`     - the spotlightObject performing the search
///      * `message` - the message to the callback, in this case "didStart"
///
///    * obj, "inProgress", updateTable -- occurs during the initial gathering phase at intervals set by the [hs.spotlight:updateInterval](#updateInterval) method.
///      * `obj`         - the spotlightObject performing the search
///      * `message`     - the message to the callback, in this case "inProgress"
///      * `updateTable` - a table containing one or more of the following keys:
///        * `kMDQueryUpdateAddedItems`   - an array table of spotlightItem objects that have been added to the results
///        * `kMDQueryUpdateChangedItems` - an array table of spotlightItem objects that have changed since they were first added to the results
///        * `kMDQueryUpdateRemovedItems` - an array table of spotlightItem objects that have been removed since they were first added to the results
///
///    * obj, "didFinish" -- occurs when the initial gathering phase of a Spotlight search completes.
///      * `obj`     - the spotlightObject performing the search
///      * `message` - the message to the callback, in this case "didFinish"
///
///    * obj, "didUpdate", updateTable -- occurs after the initial gathering phase has completed. This indicates that a change has occurred after the initial query that affects the result set.
///      * `obj`         - the spotlightObject performing the search
///      * `message`     - the message to the callback, in this case "didUpdate"
///      * `updateTable` - a table containing one or more of the keys described for the `updateTable` argument of the "inProgress" message.
///
///  * All of the results are always available through the [hs.spotlight:resultAtIndex](#resultAtIndex) method and metamethod shortcuts described in the `hs.spotlight` and `hs.spotlight.item` documentation headers; the results provided by the "didUpdate" and "inProgress" messages are just a convenience and can be used if you wish to parse partial results.
static int spotlight_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    HSMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    query.callbackRef = [skin luaUnref:refTable ref:query.callbackRef] ;
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2) ;
        query.callbackRef = [skin luaRef:refTable] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

// wrapped in init.lua
static int spotlight_callbackMessages(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_newtable(L) ;
        if (query.wantComplete) { lua_pushstring(L, "didFinish") ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; }
        if (query.wantStart)    { lua_pushstring(L, "didStart") ;   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; }
        if (query.wantUpdate)   { lua_pushstring(L, "didUpdate") ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; }
        if (query.wantProgress) { lua_pushstring(L, "inProgress") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ; }
    } else {
        NSArray *items = [skin toNSObjectAtIndex:2] ;
        if ([items isKindOfClass:[NSString class]]) items = [NSArray arrayWithObject:items] ;
        if (![items isKindOfClass:[NSArray class]]) {
            return luaL_argerror(L, 2, "expected string or array of strings") ;
        }
        NSString __block *errorMessage ;
        NSArray *messages = @[ @"didFinish", @"didStart", @"didUpdate", @"inProgress" ] ;
        [items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj isKindOfClass:[NSString class]]) {
                if (![messages containsObject:(NSString *)obj]) {
                    errorMessage = [NSString stringWithFormat:@"index %lu must be one of '%@'", idx + 1, [messages componentsJoinedByString:@"', '"]] ;
                    *stop = YES ;
                }
            } else {
                errorMessage = [NSString stringWithFormat:@"index %lu is not a string", idx + 1] ;
                *stop = YES ;
            }
        }] ;
        if (errorMessage) {
            return luaL_argerror(L, 2, errorMessage.UTF8String) ;
        } else {
            query.wantComplete = [items containsObject:@"didFinish"] ;
            query.wantStart    = [items containsObject:@"didStart"] ;
            query.wantUpdate   = [items containsObject:@"didUpdate"] ;
            query.wantProgress = [items containsObject:@"inProgress"] ;
            lua_pushvalue(L, 1) ;
        }
    }
    return 1 ;
}

/// hs.spotlight:updateInterval([interval]) -> number | spotlightObject
/// Method
/// Get or set the time interval at which the spotlightObject will send "didUpdate" messages during the initial gathering phase.
///
/// Parameters:
///  * `interval` - an optional number, default 1.0, specifying how often in seconds the "didUpdate" message should be generated during the initial gathering phase of a Spotlight query.
///
/// Returns:
///  * if an argument is provided, returns the spotlightObject object; otherwise returns the current value.
static int spotlight_updateInterval(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, query.metadataSearch.notificationBatchingInterval) ;
    } else {
        query.metadataSearch.notificationBatchingInterval = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// wrapped in init.lua
static int spotlight_sortDescriptors(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:query.metadataSearch.sortDescriptors] ;
    } else {
        NSMutableArray *newDescriptors = [[NSMutableArray alloc] init] ;
        NSArray        *hopefuls       = [skin toNSObjectAtIndex:2] ;
        NSString __block *errorMessage ;
        if (hopefuls) {
            if (![hopefuls isKindOfClass:[NSArray class]]) hopefuls = [NSArray arrayWithObject:hopefuls] ;
            if ([hopefuls isKindOfClass:[NSArray class]]) {
                [hopefuls enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj isKindOfClass:[NSSortDescriptor class]]) {
                        [newDescriptors addObject:obj] ;
                    } else {
                        [skin pushNSObject:obj] ;
                        NSSortDescriptor *candidate = toNSSortDescriptorFromLua(L, -1) ;
                        if (candidate) {
                            [newDescriptors addObject:candidate] ;
                        } else {
                            errorMessage = [NSString stringWithFormat:@"expected string or NSSortDescriptor table at index %lu", idx + 1] ;
                            *stop = YES ;
                        }
                        lua_pop(L, 1) ;
                    }
                }] ;
            } else {
                errorMessage = @"expected an array of sort descriptors" ;
            }
        } else {
            errorMessage = @"unexpected type conversion error" ;
        }
        if (errorMessage) {
            return luaL_argerror(L, 2, errorMessage.UTF8String) ;
        } else {
            query.metadataSearch.sortDescriptors = newDescriptors ;
            lua_pushvalue(L, 1) ;
        }
    }
    return 1 ;
}

// wrapped in init.lua
static int spotlight_valueListAttributes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:query.metadataSearch.valueListAttributes] ;
    } else {
        NSArray *newAttributes = [skin toNSObjectAtIndex:2] ;
        if ([newAttributes isKindOfClass:[NSString class]]) newAttributes = [NSArray arrayWithObject:newAttributes] ;
        NSString __block *errorMessage ;
        if ([newAttributes isKindOfClass:[NSArray class]]) {
            [newAttributes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if (![obj isKindOfClass:[NSString class]]) {
                    errorMessage = [NSString stringWithFormat:@"expected string at index %lu", idx + 1] ;
                    *stop = YES ;
                }
            }] ;
        } else {
            errorMessage = @"expected an array of attribute strings" ;
        }
        if (errorMessage) {
            return luaL_argerror(L, 2, errorMessage.UTF8String) ;
        } else {
            query.metadataSearch.valueListAttributes = newAttributes ;
            lua_pushvalue(L, 1) ;
        }
    }
    return 1 ;
}

// wrapped in init.lua
static int spotlight_groupingAttributes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:query.metadataSearch.groupingAttributes] ;
    } else {
        NSArray *newAttributes = [skin toNSObjectAtIndex:2] ;
        if ([newAttributes isKindOfClass:[NSString class]]) newAttributes = [NSArray arrayWithObject:newAttributes] ;
        NSString __block *errorMessage ;
        if ([newAttributes isKindOfClass:[NSArray class]]) {
            [newAttributes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if (![obj isKindOfClass:[NSString class]]) {
                    errorMessage = [NSString stringWithFormat:@"expected string at index %lu", idx + 1] ;
                    *stop = YES ;
                }
            }] ;
        } else {
            errorMessage = @"expected an array of attribute strings" ;
        }
        if (errorMessage) {
            return luaL_argerror(L, 2, errorMessage.UTF8String) ;
        } else {
            query.metadataSearch.groupingAttributes = newAttributes ;
            lua_pushvalue(L, 1) ;
        }
    }
    return 1 ;
}

/// hs.spotlight:start() -> spotlightObject
/// Method
/// Begin the gathering phase of a Spotlight query.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the spotlightObject
///
/// Notes:
///  * If the query string set with [hs.spotlight:queryString](#queryString) is invalid, an error message will be logged to the Hammerspoon console and the query will not start.  You can test to see if the query is actually running with the [hs.spotlight:isRunning](#isRunning) method.
static int spotlight_start(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    if (query.metadataSearch.started && !query.metadataSearch.stopped) {
        [skin logInfo:@"query already started"] ;
    } else {
        if (query.metadataSearch.predicate) {
            [query.metadataSearch.operationQueue addOperationWithBlock:^{
                @try {
                    [query.metadataSearch startQuery];
                } @catch(NSException *exception) {
                    [LuaSkin logError:[NSString stringWithFormat:@"%s:start error:%@", USERDATA_TAG, exception.reason]] ;
                    [query.metadataSearch stopQuery] ;
                }
            }];
        } else {
            return luaL_error(L, "no query defined") ;
        }
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.spotlight:stop() -> spotlightObject
/// Method
/// Stop the Spotlight query.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the spotlightObject
///
/// Notes:
///  * This method will prevent further gathering of items either during the initial gathering phase or from updates which may occur after the gathering phase; however it will not discard the results already discovered.
static int spotlight_stop(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    if (query.metadataSearch.started && !query.metadataSearch.stopped) {
        [query.metadataSearch stopQuery] ;
    } else {
        [skin logInfo:@"query not running"] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.spotlight:isRunning() -> boolean
/// Method
/// Returns a boolean specifying if the query is active or inactive.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean value of true if the query is active or false if it is inactive.
///
/// Notes:
///  * An active query may be gathering query results (in the initial gathering phase) or listening for changes which should cause a "didUpdate" message (after the initial gathering phase). To determine which state the query may be in, use the [hs.spotlight:isGathering](#isGathering) method.
static int spotlight_isRunning(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, query.metadataSearch.started && !query.metadataSearch.stopped) ;
    return 1 ;
}

/// hs.spotlight:isGathering() -> boolean
/// Method
/// Returns a boolean specifying whether or not the query is in the active gathering phase.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean value of true if the query is in the active gathering phase or false if it is not.
///
/// Notes:
///  * An inactive query will also return false for this method since an inactive query is neither gathering nor waiting for updates.  To determine if a query is active or inactive, use the [hs.spotlight:isRunning](#isRunning) method.
static int spotlight_isGathering(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, query.metadataSearch.gathering) ;
    return 1 ;
}

/// hs.spotlight:queryString(query) -> spotlightObject
/// Method
/// Specify the query string for the spotlightObject
///
/// Parameters:
///  * a string containing the query for the spotlightObject
///
/// Returns:
///  * the spotlightObject
///
/// Notes:
///  * Setting this property while a query is running stops the query and discards the current results. The receiver immediately starts a new query.
///
///  * The query string syntax is not simple enough to fully describe here.  It is a subset of the syntax supported by the Objective-C NSPredicate class.  Some references for this syntax can be found at:
///    * https://developer.apple.com/library/content/documentation/Carbon/Conceptual/SpotlightQuery/Concepts/QueryFormat.html
///    * https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Predicates/Articles/pSyntax.html
///
///  * If the query string does not conform to an NSPredicate query string, this method will return an error.  If the query string does conform to an NSPredicate query string, this method will accept the query string, but if it does not conform to the Metadata query format, which is a subset of the NSPredicate query format, the error will be generated when you attempt to start the query with [hs.spotlight:start](#start). At present, starting a query is the only way to fully guarantee that a query is in a valid format.
///
///  * Some of the query strings which have been used during the testing of this module are as follows (note that [[ ]] is a Lua string specifier that allows for double quotes in the content of the string):
///    * [[ kMDItemContentType == "com.apple.application-bundle" ]]
///    * [[ kMDItemFSName like "*Explore*" ]]
///    * [[ kMDItemFSName like "AppleScript Editor.app" or kMDItemAlternateNames like "AppleScript Editor"]]
///
///  * Not all attributes appear to be usable in a query; see `hs.spotlight.item:attributes` for a possible explanation.
///
///  * As a convenience, the __call metamethod has been setup for spotlightObject so that you can use `spotlightObject("query")` as a shortcut for `spotlightObject:queryString("query"):start`.  Because this shortcut includes an explicit start, this should be appended after you have set the callback function if you require a callback (e.g. `spotlightObject:setCallback(fn)("query")`).
static int spotlight_predicate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL |LS_TOPTIONAL, LS_TBREAK] ;
    HSMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:[query.metadataSearch.predicate predicateFormat]] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            query.metadataSearch.predicate = nil ;
        } else {
            NSString *errorMessage ;
            @try {
                NSPredicate *queryPredicate = [NSPredicate predicateWithFormat:[skin toNSObjectAtIndex:2]] ;
                query.metadataSearch.predicate = queryPredicate ;
            } @catch(NSException *exception) {
                errorMessage = exception.reason ;
            }
            if (errorMessage) return luaL_argerror(L, 2, errorMessage.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.spotlight:count() -> integer
/// Method
/// Returns the number of results for the spotlightObject's query
///
/// Parameters:
///  * None
///
/// Returns:
///  * if the query has collected results, returns the number of results that match the query; if the query has not been started, this value will be 0.
///
/// Notes:
///  * Just because the result of this method is 0 does not mean that the query has not been started; the query itself may not match any entries in the Spotlight database.
///  * A query which ran in the past but has been subsequently stopped will retain its queries unless the parameters have been changed.  The result of this method will indicate the number of results still attached to the query, even if it has been previously stopped.
///
///  * For convenience, metamethods have been added to the spotlightObject which allow you to use `#spotlightObject` as a shortcut for `spotlightObject:count()`.
static int spotlight_resultCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, (lua_Integer)query.metadataSearch.resultCount) ;
    return 1 ;
}

/// hs.spotlight:resultAtIndex(index) -> spotlightItemObject
/// Method
/// Returns the spotlightItemObject at the specified index of the spotlightObject
///
/// Parameters:
///  * `index` - an integer specifying the index of the result to return.
///
/// Returns:
///  * the spotlightItemObject at the specified index or an error if the index is out of bounds.
///
/// Notes:
///  * For convenience, metamethods have been added to the spotlightObject which allow you to use `spotlightObject[index]` as a shortcut for `spotlightObject:resultAtIndex(index)`.
static int spotlight_resultAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER| LS_TINTEGER, LS_TBREAK] ;
    HSMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    lua_Integer index = lua_tointeger(L, 2) ;
    NSUInteger  count = query.metadataSearch.resultCount ;
    if (index < 1 || index >(lua_Integer)count) {
        if (count == 0) {
            return luaL_argerror(L, 2, "result set is empty") ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index must be between 1 and %lu inclusive", count] UTF8String]) ;
        }
    } else {
        [query.metadataSearch disableUpdates] ;
        NSMetadataItem *item = [query.metadataSearch resultAtIndex:(NSUInteger)(index - 1)] ;
        [query.metadataSearch enableUpdates] ;
        [skin pushNSObject:item] ;
    }
    return 1 ;
}

/// hs.spotlight:valueLists() -> table
/// Method
/// Returns the value list summaries for the Spotlight query
///
/// Parameters:
///  * None
///
/// Returns:
///  * an array table of the value list summaries for the Spotlight query as specified by the [hs.spotlight:valueListAttributes](#valueListAttributes) method.  Each member of the array will be a table with the following keys:
///    * `attribute` - the attribute for the summary
///    * `value`     - the value of the attribute for the summary
///    * `count`     - the number of Spotlight items in the spotlightObject results for which this attribute has this value
///
/// Notes:
///  * Value list summaries are a quick way to gather statistics about the number of results which match certain criteria - they do not allow you easy access to the matching members, just information about their numbers.
static int spotlight_valueLists(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:query.metadataSearch.valueLists] ;
    return 1 ;
}

/// hs.spotlight:groupedResults() -> table
/// Method
/// Returns the grouped results for a Spotlight query.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an array table containing the grouped results for the Spotlight query as specified by the [hs.spotlight:groupingAttributes](#groupingAttributes) method.  Each member of the array will be a spotlightGroupObject which is detailed in the `hs.spotlight.group` module documentation.
///
/// Notes:
///  * The spotlightItemObjects available with the `hs.spotlight.group:resultAtIndex` method are the subset of the full results of the spotlightObject that match the attribute and value of the spotlightGroupObject.  The same item is available through the spotlightObject and the spotlightGroupObject, though likely at different indicies.
static int spotlight_groupedResults(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSMetadataQuery *query = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:query.metadataSearch.groupedResults] ;
    return 1 ;
}

#pragma mark - Module Group Methods

/// hs.spotlight.group:attribute() -> string
/// Method
/// Returns the name of the attribute the spotlightGroupObject results are grouped by.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the attribute name as a string
static int group_attribute(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, GROUP_UD_TAG, LS_TBREAK] ;
    NSMetadataQueryResultGroup *resultGroup = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:resultGroup.attribute] ;
    return 1 ;
}

/// hs.spotlight.group:value() -> value
/// Method
/// Returns the value for the attribute the spotlightGroupObject results are grouped by.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the attribute value as an appropriate data type
static int group_value(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, GROUP_UD_TAG, LS_TBREAK] ;
    NSMetadataQueryResultGroup *resultGroup = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:resultGroup.value] ;
    return 1 ;
}

/// hs.spotlight.group:count() -> integer
/// Method
/// Returns the number of query results contained in the spotlightGroupObject.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an integer specifying the number of results that match the attribute and value represented by this spotlightGroup object.
///
/// Notes:
///  * For convenience, metamethods have been added to the spotlightGroupObject which allow you to use `#spotlightGroupObject` as a shortcut for `spotlightGroupObject:count()`.
static int group_resultCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, GROUP_UD_TAG, LS_TBREAK] ;
    NSMetadataQueryResultGroup *resultGroup = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, (lua_Integer)resultGroup.resultCount) ;
    return 1 ;
}

/// hs.spotlight.group:resultAtIndex(index) -> spotlightItemObject
/// Method
/// Returns the spotlightItemObject at the specified index of the spotlightGroupObject
///
/// Parameters:
///  * `index` - an integer specifying the index of the result to return.
///
/// Returns:
///  * the spotlightItemObject at the specified index or an error if the index is out of bounds.
///
/// Notes:
///  * For convenience, metamethods have been added to the spotlightGroupObject which allow you to use `spotlightGroupObject[index]` as a shortcut for `spotlightGroupObject:resultAtIndex(index)`.
static int group_resultAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, GROUP_UD_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    NSMetadataQueryResultGroup *resultGroup = [skin toNSObjectAtIndex:1] ;

    lua_Integer index = lua_tointeger(L, 2) ;
    NSUInteger  count = resultGroup.resultCount ;
    if (index < 1 || index >(lua_Integer)count) {
        if (count == 0) {
            return luaL_argerror(L, 2, "result set is empty") ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index must be between 1 and %lu inclusive", count] UTF8String]) ;
        }
    } else {
        [skin pushNSObject:[resultGroup resultAtIndex:(NSUInteger)(index - 1)]] ;
    }
    return 1 ;
}

/// hs.spotlight.group:subgroups() -> table
/// Method
/// Returns the subgroups of the spotlightGroupObject
///
/// Parameters:
///  * None
///
/// Returns:
///  * an array table containing the subgroups of the spotlightGroupObject or nil if no subgroups exist
///
/// Notes:
///  * Subgroups are created when you supply more than one grouping attribute to `hs.spotlight:groupingAttributes`.
static int group_subgroups(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, GROUP_UD_TAG, LS_TBREAK] ;
    NSMetadataQueryResultGroup *resultGroup = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:resultGroup.subgroups] ;
    return 1 ;
}

#pragma mark - Module Item Methods

/// hs.spotlight.item:attributes() -> table
/// Method
/// Returns a list of attributes associated with the spotlightItemObject
///
/// Parameters:
///  * None
///
/// Returns:
///  * an array table containing a list of attributes associated with the result item.
///
/// Notes:
///  * This list of attributes is usually not a complete list of the attributes available for a given spotlightItemObject. Many of the known attribute names are included in the `hs.spotlight.commonAttributeKeys` constant array, but even this is not an exhaustive list -- an application may create and assign any key it wishes to an entity for inclusion in the Spotlight metadata database.
///
/// * A common attribute, which is not usually included in the results of this method is the "kMDItemPath" attribute which specifies the local path to the file the entity represents. This is included here for reference, as it is a commonly desired value that is not obviously available for almost all Spotlight entries.
///  * It is believed that only those keys which are explicitly set when an item is added to the Spotlight database are included in the array returned by this method. Any attribute which is calculated or restricted in a sandboxed application appears to require an explicit request. This is, however, conjecture, and when in doubt you should explicitly check for the attributes you require with [hs.spotlight.item:valueForAttribute](#valueForAttribute) and not rely solely on the results from this method.
static int item_attributes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, ITEM_UD_TAG, LS_TBREAK] ;
    NSMetadataItem *item = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:item.attributes] ;
    return 1 ;
}

/// hs.spotlight.item:valueForAttribute(attribute) -> value
/// Method
/// Returns the value for the specified attribute of the spotlightItemObject
///
/// Parameters:
///  * `attribute` - a string specifying the attribute to get the value of for the spotlightItemObject
///
/// Returns:
///  * the attribute value as an appropriate data type or nil if the attribute does not exist or contains no value
///
/// Notes:
///  * See [hs.spotlight.item:attributes](#attributes) for information about possible attribute names.
///
///  * For convenience, metamethods have been added to the spotlightItemObject which allow you to use `spotlightItemObject.attribute` as a shortcut for `spotlightItemObject:valueForAttribute(attribute)`.
static int item_valueForAttribute(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, ITEM_UD_TAG, LS_TSTRING, LS_TBREAK] ;
    NSMetadataItem *item = [skin toNSObjectAtIndex:1] ;

    NSString *attribute = [skin toNSObjectAtIndex:2] ;
    [skin pushNSObject:[item valueForAttribute:attribute] withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

#pragma mark - Module Constants

/// hs.spotlight.definedSearchScopes[]
/// Constant
/// A table of key-value pairs describing predefined search scopes for Spotlight queries
///
/// The keys for this table are as follows:
///  * `iCloudData`              - Search all files not in the Documents directories of the app’s iCloud container directories.
///  * `iCloudDocuments`         - Search all files in the Documents directories of the app’s iCloud container directories.
///  * `iCloudExternalDocuments` - Search for documents outside the app’s container.
///  * `indexedLocalComputer`    - Search all indexed local mounted volumes including the current user’s home directory (even if the home directory is remote).
///  * `indexedNetwork`          - Search all indexed user-mounted remote volumes.
///  * `localComputer`           - Search all local mounted volumes, including the user home directory. The user’s home directory is searched even if it is a remote volume.
///  * `network`                 - Search all user-mounted remote volumes.
///  * `userHome`                - Search the user’s home directory.
///
/// Notes:
///  * It is uncertain at this time if the `iCloud*` search scopes are actually useful within Hammerspoon as Hammerspoon is not a sandboxed application that uses the iCloud API fo document storage. Further information on your experiences with these scopes, if you use them, is welcome in the Hammerspoon Google Group or at the Hammerspoon Github web site.
static int push_searchScopes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    lua_newtable(L) ;
    [skin pushNSObject:NSMetadataQueryUserHomeScope] ;                              lua_setfield(L, -2, "userHome") ;
    [skin pushNSObject:NSMetadataQueryLocalComputerScope] ;                         lua_setfield(L, -2, "localComputer") ;
    [skin pushNSObject:NSMetadataQueryNetworkScope] ;                               lua_setfield(L, -2, "network") ;
    [skin pushNSObject:NSMetadataQueryUbiquitousDocumentsScope] ;                   lua_setfield(L, -2, "iCloudDocuments") ;
    [skin pushNSObject:NSMetadataQueryUbiquitousDataScope] ;                        lua_setfield(L, -2, "iCloudData") ;
    [skin pushNSObject:NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope] ; lua_setfield(L, -2, "iCloudExternalDocuments") ;
    [skin pushNSObject:NSMetadataQueryIndexedLocalComputerScope] ;                  lua_setfield(L, -2, "indexedLocalComputer") ;
    [skin pushNSObject:NSMetadataQueryIndexedNetworkScope] ;                        lua_setfield(L, -2, "indexedNetwork") ;
    return 1 ;
}

/// hs.spotlight.commonAttributeKeys[]
/// Constant
/// A list of defined attribute keys as discovered in the macOS 10.12 SDK framework headers.
///
/// This table contains a list of attribute strings that may be available for spotlightSearch result items.  This list is by no means complete, and not every result will contain all or even most of these keys.
///
/// Notes:
///  * This list was generated by searching the Framework header files for string constants which matched one of the following regular expressions: "kMDItem.+", "NSMetadataItem.+", and "NSMetadataUbiquitousItem.+"
static int push_commonAttributeKeys(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    lua_newtable(L) ;

    // pulled from 10.12 framework headers based on string names "kMDItem.+", "NSMetadataItem.+", and
    // "NSMetadataUbiquitousItem.+" then duplicate values removed

    [skin pushNSObject:(__bridge NSString *)kMDItemFSHasCustomIcon] ;            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kMDItemFSInvisible] ;                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kMDItemFSIsExtensionHidden] ;        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kMDItemFSIsStationery] ;             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kMDItemFSLabel] ;                    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kMDItemFSNodeCount] ;                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kMDItemFSOwnerGroupID] ;             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kMDItemFSOwnerUserID] ;              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:(__bridge NSString *)kMDItemHTMLContent] ;                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;

    [skin pushNSObject:NSMetadataItemAcquisitionMakeKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAcquisitionModelKey] ;                      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAlbumKey] ;                                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAltitudeKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemApertureKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAppleLoopDescriptorsKey] ;                  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAppleLoopsKeyFilterTypeKey] ;               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAppleLoopsLoopModeKey] ;                    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAppleLoopsRootKeyKey] ;                     lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemApplicationCategoriesKey] ;                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAttributeChangeDateKey] ;                   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAudiencesKey] ;                             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAudioBitRateKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAudioChannelCountKey] ;                     lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAudioEncodingApplicationKey] ;              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAudioSampleRateKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAudioTrackNumberKey] ;                      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAuthorAddressesKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAuthorEmailAddressesKey] ;                  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemAuthorsKey] ;                               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemBitsPerSampleKey] ;                         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemCameraOwnerKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemCFBundleIdentifierKey] ;                    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemCityKey] ;                                  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemCodecsKey] ;                                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemColorSpaceKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemCommentKey] ;                               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemComposerKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemContactKeywordsKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemContentCreationDateKey] ;                   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemContentModificationDateKey] ;               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemContentTypeKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemContentTypeTreeKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemContributorsKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemCopyrightKey] ;                             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemCountryKey] ;                               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemCoverageKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemCreatorKey] ;                               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemDateAddedKey] ;                             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemDeliveryTypeKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemDescriptionKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemDirectorKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemDisplayNameKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemDownloadedDateKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemDueDateKey] ;                               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemDurationSecondsKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemEditorsKey] ;                               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemEmailAddressesKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemEncodingApplicationsKey] ;                  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemExecutableArchitecturesKey] ;               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemExecutablePlatformKey] ;                    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemEXIFGPSVersionKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemEXIFVersionKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemExposureModeKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemExposureProgramKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemExposureTimeSecondsKey] ;                   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemExposureTimeStringKey] ;                    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemFinderCommentKey] ;                         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemFlashOnOffKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemFNumberKey] ;                               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemFocalLength35mmKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemFocalLengthKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemFontsKey] ;                                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemFSContentChangeDateKey] ;                   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemFSCreationDateKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemFSNameKey] ;                                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemFSSizeKey] ;                                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGenreKey] ;                                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSAreaInformationKey] ;                    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSDateStampKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSDestBearingKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSDestDistanceKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSDestLatitudeKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSDestLongitudeKey] ;                      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSDifferentalKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSDOPKey] ;                                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSMapDatumKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSMeasureModeKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSProcessingMethodKey] ;                   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSStatusKey] ;                             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemGPSTrackKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemHasAlphaChannelKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemHeadlineKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemIdentifierKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemImageDirectionKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemInformationKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemInstantMessageAddressesKey] ;               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemInstructionsKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemIsApplicationManagedKey] ;                  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemIsGeneralMIDISequenceKey] ;                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemIsLikelyJunkKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemISOSpeedKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemIsUbiquitousKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemKeySignatureKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemKeywordsKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemKindKey] ;                                  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemLanguagesKey] ;                             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemLastUsedDateKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemLatitudeKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemLayerNamesKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemLensModelKey] ;                             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemLongitudeKey] ;                             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemLyricistKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemMaxApertureKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemMediaTypesKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemMeteringModeKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemMusicalGenreKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemMusicalInstrumentCategoryKey] ;             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemMusicalInstrumentNameKey] ;                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemNamedLocationKey] ;                         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemNumberOfPagesKey] ;                         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemOrganizationsKey] ;                         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemOrientationKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemOriginalFormatKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemOriginalSourceKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemPageHeightKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemPageWidthKey] ;                             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemParticipantsKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemPathKey] ;                                  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemPerformersKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemPhoneNumbersKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemPixelCountKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemPixelHeightKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemPixelWidthKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemProducerKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemProfileNameKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemProjectsKey] ;                              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemPublishersKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemRecipientAddressesKey] ;                    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemRecipientEmailAddressesKey] ;               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemRecipientsKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemRecordingDateKey] ;                         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemRecordingYearKey] ;                         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemRedEyeOnOffKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemResolutionHeightDPIKey] ;                   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemResolutionWidthDPIKey] ;                    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemRightsKey] ;                                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemSecurityMethodKey] ;                        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemSpeedKey] ;                                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemStarRatingKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemStateOrProvinceKey] ;                       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemStreamableKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemSubjectKey] ;                               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemTempoKey] ;                                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemTextContentKey] ;                           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemThemeKey] ;                                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemTimeSignatureKey] ;                         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemTimestampKey] ;                             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemTitleKey] ;                                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemTotalBitRateKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemURLKey] ;                                   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemVersionKey] ;                               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemVideoBitRateKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemWhereFromsKey] ;                            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataItemWhiteBalanceKey] ;                          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemContainerDisplayNameKey] ;        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemDownloadingErrorKey] ;            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemDownloadingStatusCurrent] ;       lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemDownloadingStatusDownloaded] ;    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemDownloadingStatusKey] ;           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemDownloadingStatusNotDownloaded] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemDownloadRequestedKey] ;           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemHasUnresolvedConflictsKey] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemIsDownloadingKey] ;               lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemIsExternalDocumentKey] ;          lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemIsUploadedKey] ;                  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemIsUploadingKey] ;                 lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemPercentDownloadedKey] ;           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemPercentUploadedKey] ;             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemUploadingErrorKey] ;              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSMetadataUbiquitousItemURLInLocalContainerKey] ;         lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;

    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSMetadataQuery(lua_State *L, id obj) {
    HSMetadataQuery *value = obj;
    value.selfPushCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSMetadataQuery *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSMetadataQueryFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSMetadataQuery *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSMetadataQuery, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushNSMetadataQueryResultGroup(lua_State *L, id obj) {
    NSMetadataQueryResultGroup *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(NSMetadataQueryResultGroup *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, GROUP_UD_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toNSMetadataQueryResultGroupFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSMetadataQueryResultGroup *value ;
    if (luaL_testudata(L, idx, GROUP_UD_TAG)) {
        value = get_objectFromUserdata(__bridge NSMetadataQueryResultGroup, L, idx, GROUP_UD_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", GROUP_UD_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushNSMetadataItem(lua_State *L, id obj) {
    NSMetadataItem *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(NSMetadataItem *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, ITEM_UD_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toNSMetadataItemFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSMetadataItem *value ;
    if (luaL_testudata(L, idx, ITEM_UD_TAG)) {
        value = get_objectFromUserdata(__bridge NSMetadataItem, L, idx, ITEM_UD_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", ITEM_UD_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushNSSortDescriptor(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSSortDescriptor *descriptor = obj ;
    lua_newtable(L) ;
    [skin pushNSObject:descriptor.key] ; lua_setfield(L, -2, "key") ;
    lua_pushboolean(L, descriptor.ascending) ; lua_setfield(L, -2, "ascending") ;
    lua_pushstring(L, "NSSortDescriptor") ; lua_setfield(L, -2, "__luaSkinType") ;
    return 1 ;
}

static id toNSSortDescriptorFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSSortDescriptor *value ;
    idx = lua_absindex(L, idx) ;
    if (lua_type(L, idx) == LUA_TSTRING) {
        value = [NSSortDescriptor sortDescriptorWithKey:[skin toNSObjectAtIndex:idx] ascending:YES] ;
    } else if (lua_type(L, idx) == LUA_TTABLE) {
        if (lua_getfield(L, idx, "key") == LUA_TSTRING) {
            NSString *key = [skin toNSObjectAtIndex:-1] ;
            BOOL     ascending = YES ;
            if (lua_getfield(L, idx, "ascending") == LUA_TBOOLEAN) {
                ascending = (BOOL)lua_toboolean(L, -1) ;
            }
            lua_pop(L, 1) ;
            value = [NSSortDescriptor sortDescriptorWithKey:key ascending:ascending] ;
        } else {
            [skin logError:@"key field missing in NSSortDescriptor table"] ;
        }
        lua_pop(L, 1) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected string or table describing an NSSortDescriptor, found %s",
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushNSMetadataQueryAttributeValueTuple(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSMetadataQueryAttributeValueTuple *tuple = obj ;
    lua_newtable(L) ;
    [skin pushNSObject:tuple.attribute] ;          lua_setfield(L, -2, "attribute") ;
    lua_pushinteger(L, (lua_Integer)tuple.count) ; lua_setfield(L, -2, "count") ;
    [skin pushNSObject:tuple.value] ;              lua_setfield(L, -2, "value") ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSMetadataQuery *obj = [skin luaObjectAtIndex:1 toClass:"HSMetadataQuery"] ;
    NSString *title = obj.metadataSearch.predicate.predicateFormat ;
    if (!title) title = @"<undefined>" ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSMetadataQuery *obj1 = [skin luaObjectAtIndex:1 toClass:"HSMetadataQuery"] ;
        HSMetadataQuery *obj2 = [skin luaObjectAtIndex:2 toClass:"HSMetadataQuery"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSMetadataQuery *obj = get_objectFromUserdata(__bridge_transfer HSMetadataQuery, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfPushCount-- ;
        if (obj.selfPushCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
            NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter] ;
            [notificationCenter removeObserver:obj name:NSMetadataQueryDidFinishGatheringNotification object:obj.metadataSearch];
            [notificationCenter removeObserver:obj name:NSMetadataQueryDidStartGatheringNotification  object:obj.metadataSearch];
            [notificationCenter removeObserver:obj name:NSMetadataQueryDidUpdateNotification          object:obj.metadataSearch];
            [notificationCenter removeObserver:obj name:NSMetadataQueryGatheringProgressNotification  object:obj.metadataSearch];
            if (!obj.metadataSearch.stopped) [obj.metadataSearch stopQuery] ;
            obj.metadataSearch = nil ;
            obj = nil ;
        }
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int group_userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSMetadataQueryResultGroup *obj = [skin luaObjectAtIndex:1 toClass:"NSMetadataQueryResultGroup"] ;
    NSString *title = obj.attribute ;
    if (!title) title = @"<undefined>" ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", GROUP_UD_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int group_userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, GROUP_UD_TAG) && luaL_testudata(L, 2, GROUP_UD_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        NSMetadataQueryResultGroup *obj1 = [skin luaObjectAtIndex:1 toClass:"NSMetadataQueryResultGroup"] ;
        NSMetadataQueryResultGroup *obj2 = [skin luaObjectAtIndex:2 toClass:"NSMetadataQueryResultGroup"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int group_userdata_gc(lua_State* L) {
    NSMetadataQueryResultGroup *obj = get_objectFromUserdata(__bridge_transfer NSMetadataQueryResultGroup, L, 1, GROUP_UD_TAG) ;
    if (obj) obj = nil ;
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int item_userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSMetadataItem *obj = [skin luaObjectAtIndex:1 toClass:"NSMetadataItem"] ;
    NSString *title = [obj valueForAttribute:NSMetadataItemFSNameKey] ;
    if (!title) title = @"<undefined>" ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", ITEM_UD_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int item_userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, ITEM_UD_TAG) && luaL_testudata(L, 2, ITEM_UD_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        NSMetadataItem *obj1 = [skin luaObjectAtIndex:1 toClass:"NSMetadataItem"] ;
        NSMetadataItem *obj2 = [skin luaObjectAtIndex:2 toClass:"NSMetadataItem"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int item_userdata_gc(lua_State* L) {
    NSMetadataItem *obj = get_objectFromUserdata(__bridge_transfer NSMetadataItem, L, 1, ITEM_UD_TAG) ;
    if (obj) obj = nil ;
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* __unused L) {
    if (moduleSearchQueue) {
        [moduleSearchQueue cancelAllOperations] ;
        [moduleSearchQueue waitUntilAllOperationsAreFinished] ;
        moduleSearchQueue = nil ;
    }
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"searchScopes",          spotlight_searchScopes},
    {"setCallback",           spotlight_callback},
    {"callbackMessages",      spotlight_callbackMessages},
    {"updateInterval",        spotlight_updateInterval},
    {"sortDescriptors",       spotlight_sortDescriptors},
    {"groupingAttributes",    spotlight_groupingAttributes},
    {"valueListAttributes",   spotlight_valueListAttributes},
    {"start",                 spotlight_start},
    {"stop",                  spotlight_stop},
    {"isRunning",             spotlight_isRunning},
    {"isGathering",           spotlight_isGathering},
    {"queryString",           spotlight_predicate},
    {"count",                 spotlight_resultCount},
    {"resultAtIndex",         spotlight_resultAtIndex},
    {"valueLists",            spotlight_valueLists},
    {"groupedResults",        spotlight_groupedResults},

    {"__tostring",            userdata_tostring},
    {"__eq",                  userdata_eq},
    {"__gc",                  userdata_gc},
    {NULL,                    NULL}
};

static const luaL_Reg item_userdata_metalib[] = {
    {"attributes",        item_attributes},
    {"valueForAttribute", item_valueForAttribute},

    {"__tostring",        item_userdata_tostring},
    {"__eq",              item_userdata_eq},
    {"__gc",              item_userdata_gc},
    {NULL,                NULL}
};

static const luaL_Reg group_userdata_metalib[] = {
    {"attribute",     group_attribute},
    {"value",         group_value},
    {"count",         group_resultCount},
    {"resultAtIndex", group_resultAtIndex},
    {"subgroups",     group_subgroups},

    {"__tostring",    group_userdata_tostring},
    {"__eq",          group_userdata_eq},
    {"__gc",          group_userdata_gc},
    {NULL,            NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",       spotlight_new},
    {"newWithin", spotlight_searchWithin},
    {NULL,        NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs_spotlight_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerObject:ITEM_UD_TAG  objectFunctions:item_userdata_metalib] ;
    [skin registerObject:GROUP_UD_TAG objectFunctions:group_userdata_metalib] ;

    push_searchScopes(L) ;        lua_setfield(L, -2, "definedSearchScopes") ;
    push_commonAttributeKeys(L) ; lua_setfield(L, -2, "commonAttributeKeys") ;

    [skin registerPushNSHelper:pushHSMetadataQuery                   forClass:"HSMetadataQuery"];
    [skin registerLuaObjectHelper:toHSMetadataQueryFromLua           forClass:"HSMetadataQuery"
                                                          withUserdataMapping:USERDATA_TAG];

    [skin registerPushNSHelper:pushNSMetadataItem                     forClass:"NSMetadataItem"] ;
    [skin registerLuaObjectHelper:toNSMetadataItemFromLua             forClass:"NSMetadataItem"
                                                           withUserdataMapping:ITEM_UD_TAG];

    [skin registerPushNSHelper:pushNSMetadataQueryResultGroup         forClass:"NSMetadataQueryResultGroup"];
    [skin registerLuaObjectHelper:toNSMetadataQueryResultGroupFromLua forClass:"NSMetadataQueryResultGroup"
                                                           withUserdataMapping:GROUP_UD_TAG];

    [skin registerPushNSHelper:pushNSMetadataQueryAttributeValueTuple forClass:"NSMetadataQueryAttributeValueTuple"] ;

    [skin registerPushNSHelper:pushNSSortDescriptor                   forClass:"NSSortDescriptor"] ;
    [skin registerLuaObjectHelper:toNSSortDescriptorFromLua           forClass:"NSSortDescriptor"
                                                              withTableMapping:"NSSortDescriptor"] ;

    return 1;
}
