#import "webview.h"

static LSRefTable      refTable = LUA_NOREF;
static NSMutableArray *identifiersInUse ;

// @encode is a compiler directive which may give different answers on different architectures,
// so instead lets capture the value with the same method we use for testing later on...
static const char *boolEncodingType ;

// Can't have "static" or "constant" dynamic NSObjects like NSArray, so define in lua_open
static NSArray *builtinToolbarItems;
static NSArray *automaticallyIncluded ;
static NSArray *keysToKeepFromDefinitionDictionary ;
// static NSArray *keysToKeepFromGroupDefinition ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

@interface MJConsoleWindowController : NSWindowController
+ (instancetype)singleton;
- (void)setup;
@end

@interface HSToolbarSearchField : NSSearchField
@property (weak) NSToolbarItem *toolbarItem ;
@property        BOOL          releaseOnCallback ;

- (void)searchCallback:(NSMenuItem *)sender ;
@end

@interface HSToolbar : NSToolbar <NSToolbarDelegate>
@property            int                 selfRef;
@property            int                 callbackRef;
@property            BOOL                notifyToolbarChanges ;
@property (weak)     NSWindow            *windowUsingToolbar ;
@property (readonly) NSMutableOrderedSet *allowedIdentifiers ;
@property (readonly) NSMutableOrderedSet *defaultIdentifiers ;
@property (readonly) NSMutableOrderedSet *selectableIdentifiers ;
@property (readonly) NSMutableDictionary *itemDefDictionary ;
// These can differ if the toolbar is in multiple windows
@property (readonly) NSMutableDictionary *fnRefDictionary ;
@property (readonly) NSMutableDictionary *enabledDictionary ;
@end

#pragma mark - Support Functions and Classes

// Create the default searchField menu: Recent Searches, Clear, etc.
static NSMenu *createCoreSearchFieldMenu() {
    NSMenu *searchMenu = [[NSMenu alloc] initWithTitle:@"Search Menu"];
    searchMenu.autoenablesItems = YES;

    NSMenuItem *recentsTitleItem = [[NSMenuItem alloc] initWithTitle:@"Recent Searches" action:nil keyEquivalent:@""];
    recentsTitleItem.tag         = NSSearchFieldRecentsTitleMenuItemTag;
    [searchMenu insertItem:recentsTitleItem atIndex:0];

    NSMenuItem *norecentsTitleItem = [[NSMenuItem alloc] initWithTitle:@"No recent searches" action:nil keyEquivalent:@""];
    norecentsTitleItem.tag         = NSSearchFieldNoRecentsMenuItemTag;
    [searchMenu insertItem:norecentsTitleItem atIndex:1];

    NSMenuItem *recentsItem = [[NSMenuItem alloc] initWithTitle:@"Recents" action:nil keyEquivalent:@""];
    recentsItem.tag         = NSSearchFieldRecentsMenuItemTag;
    [searchMenu insertItem:recentsItem atIndex:2];

    NSMenuItem *separatorItem = (NSMenuItem*)[NSMenuItem separatorItem];
    [searchMenu insertItem:separatorItem atIndex:3];

    NSMenuItem *clearItem = [[NSMenuItem alloc] initWithTitle:@"Clear" action:nil keyEquivalent:@""];
    clearItem.tag         = NSSearchFieldClearRecentsMenuItemTag;
    [searchMenu insertItem:clearItem atIndex:4];
    return searchMenu ;
}

@implementation HSToolbar
- (instancetype)initWithIdentifier:(NSString *)identifier itemTableIndex:(int)idx andState:(lua_State *)L {
    self = [super initWithIdentifier:identifier] ;
    if (self) {
        _allowedIdentifiers    = [[NSMutableOrderedSet alloc] init] ;
        _defaultIdentifiers    = [[NSMutableOrderedSet alloc] init] ;
        _selectableIdentifiers = [[NSMutableOrderedSet alloc] init] ;
        _itemDefDictionary     = [[NSMutableDictionary alloc] init] ;
        _fnRefDictionary       = [[NSMutableDictionary alloc] init] ;
        _enabledDictionary     = [[NSMutableDictionary alloc] init] ;

        _callbackRef           = LUA_NOREF;
        _selfRef               = LUA_NOREF;
        _windowUsingToolbar    = nil ;
        _notifyToolbarChanges  = NO ;

        [_allowedIdentifiers addObjectsFromArray:automaticallyIncluded] ;

        if (idx != LUA_NOREF) {
            LuaSkin     *skin      = [LuaSkin sharedWithState:L] ;
//             lua_State   *L         = [skin L] ;
            lua_Integer count      = luaL_len(L, idx) ;
            lua_Integer index      = 0 ;
            BOOL        isGood     = YES ;

            idx = lua_absindex(L, idx) ;
            while (isGood && (index < count)) {
                if (lua_rawgeti(L, idx, index + 1) == LUA_TTABLE) {
                    isGood = [self addToolbarDefinitionAtIndex:-1 withState:L] ;
                } else {
                    [skin logWarn:[NSString stringWithFormat:@"%s:not a table at index %lld in toolbar %@", USERDATA_TB_TAG, index + 1, identifier]] ;
                    isGood = NO ;
                }
                lua_pop(L, 1) ;
                index++ ;
            }

            if (!isGood) {
                [skin logError:[NSString stringWithFormat:@"%s:malformed toolbar items encountered", USERDATA_TB_TAG]] ;
                return nil ;
            }
        }

        self.allowsUserCustomization = NO ;
        if ([self respondsToSelector:@selector(allowsExtensionItems)]) {
            self.allowsExtensionItems    = NO ;
        }
        self.autosavesConfiguration  = NO ;
        self.delegate                = self ;
    }
    return self ;
}

- (instancetype)initWithCopy:(HSToolbar *)original andState:(lua_State *)L{
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    self = [super initWithIdentifier:original.identifier] ;
    if (self) {
        _selfRef               = LUA_NOREF;
        _callbackRef           = LUA_NOREF ;
        if (original.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:original.callbackRef] ;
            _callbackRef = [skin luaRef:refTable] ;
        }
        _allowedIdentifiers    = original.allowedIdentifiers ;
        _defaultIdentifiers    = original.defaultIdentifiers ;
        _selectableIdentifiers = original.selectableIdentifiers ;
        _notifyToolbarChanges  = original.notifyToolbarChanges ;
        _windowUsingToolbar    = nil ;

        self.allowsUserCustomization = original.allowsUserCustomization ;
        self.allowsExtensionItems    = original.allowsExtensionItems ;
        self.autosavesConfiguration  = original.autosavesConfiguration ;

        _itemDefDictionary = original.itemDefDictionary ;
        _enabledDictionary = [[NSMutableDictionary alloc] initWithDictionary:original.enabledDictionary
                                                                   copyItems:YES] ;
        _fnRefDictionary   = [[NSMutableDictionary alloc] init] ;
        for (NSString *key in [original.fnRefDictionary allKeys]) {
            int theRef = [[original.fnRefDictionary objectForKey:key] intValue] ;
            if (theRef != LUA_NOREF) {
                [skin pushLuaRef:refTable ref:theRef] ;
                theRef = [skin luaRef:refTable] ;
            }
            _fnRefDictionary[key] = @(theRef) ;
        }

        self.delegate = self ;
    }
    return self ;
}

- (void)performCallback:(id)sender{
    NSString      *searchText = nil ;
    NSToolbarItem *item       = nil ;
    int           argCount    = 3 ;

    if ([sender isKindOfClass:[NSToolbarItem class]]) {
        item = sender ;
    } else if ([sender isKindOfClass:[HSToolbarSearchField class]]) {
        searchText = [sender stringValue] ;
        item       = [sender toolbarItem] ;
        argCount++ ;
        if (((HSToolbarSearchField *)sender).releaseOnCallback) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [((HSToolbarSearchField *)sender).window makeFirstResponder:((HSToolbarSearchField *)sender).window.contentView] ;
            }) ;
        }
    } else {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:Unknown object sent to callback:%@", USERDATA_TB_TAG, [sender debugDescription]]] ;
        return ;
    }

    NSNumber *theFnRef = [_fnRefDictionary objectForKey:[item itemIdentifier]] ;
    int itemFnRef = theFnRef ? [theFnRef intValue] : LUA_NOREF ;
    int fnRef = (itemFnRef != LUA_NOREF) ? itemFnRef : _callbackRef ;
    if (fnRef != LUA_NOREF) { // should we bother dispatching?
        dispatch_async(dispatch_get_main_queue(), ^{
            if (fnRef != LUA_NOREF) { // now make sure it's still valid
                NSWindow  *ourWindow = self.windowUsingToolbar ;
                LuaSkin   *skin      = [LuaSkin sharedWithState:NULL] ;
                lua_State *L         = [skin L] ;
                _lua_stackguard_entry(L);
                [skin pushLuaRef:refTable ref:fnRef] ;
                [skin pushNSObject:self] ;
                if (ourWindow) {
                    if ([ourWindow isEqualTo:[[MJConsoleWindowController singleton] window]]) {
                        lua_pushstring(L, "console") ;
                    } else if (ourWindow.windowController) { // hs.chooser
                        [skin pushNSObject:ourWindow.windowController withOptions:LS_NSDescribeUnknownTypes] ;
                    } else {
                        [skin pushNSObject:ourWindow withOptions:LS_NSDescribeUnknownTypes] ;
                    }
                } else {
                    // shouldn't be possible, but just in case...
                    lua_pushstring(L, "** no window attached") ;
                }
                [skin pushNSObject:[item itemIdentifier]] ;
                if (argCount == 4) [skin pushNSObject:searchText] ;
                [skin protectedCallAndError:[NSString stringWithFormat:@"hs.webview.toolbar item callback (%@)", item.itemIdentifier] nargs:argCount nresults:0];
                _lua_stackguard_exit(L);
            }
        }) ;
    }
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem {
    // default to YES
    return _enabledDictionary[theItem.itemIdentifier] ? [_enabledDictionary[theItem.itemIdentifier] boolValue] : YES ;
}

- (BOOL)isAttachedToWindow {
    NSWindow *ourWindow = _windowUsingToolbar ;
    BOOL attached       = ourWindow && [self isEqualTo:[ourWindow toolbar]] ;
    if (!attached) ourWindow = nil ; // just to keep it correct
    return attached ;
}

// TODO ? if validate of data method added, use here during construction

- (BOOL)addToolbarDefinitionAtIndex:(int)idx withState:(lua_State *)L {
    LuaSkin   *skin      = [LuaSkin sharedWithState:L] ;
//     lua_State *L         = [skin L] ;
    idx = lua_absindex(L, idx) ;

    NSString *identifier = (lua_getfield(L, -1, "id") == LUA_TSTRING) ?
                                          [skin toNSObjectAtIndex:-1] : nil ;
    lua_pop(L, 1) ;

    // Make sure unique
    if (!identifier) {
        [skin  logWarn:[NSString stringWithFormat:@"%s:id must be present, and it must be a string",
                                                   USERDATA_TB_TAG]] ;
        return NO ;
    } else if ([_itemDefDictionary objectForKey:identifier]) {
        [skin  logWarn:[NSString stringWithFormat:@"%s:identifier %@ must be unique or a system defined item",
                                                   USERDATA_TB_TAG, identifier]] ;
        return NO ;
    }

    // Get fields that are stored outside of the item definition
    BOOL selectable   = (lua_getfield(L, idx, "selectable") == LUA_TBOOLEAN) ? (BOOL)lua_toboolean(L, -1) : NO ;
    BOOL allowedAlone = (lua_getfield(L, idx, "allowedAlone") == LUA_TBOOLEAN) ? (BOOL)lua_toboolean(L, -1) : YES ;
    BOOL included     = (lua_getfield(L, idx, "default") == LUA_TBOOLEAN) ? (BOOL)lua_toboolean(L, -1) : allowedAlone ;
    lua_pop(L, 3) ;

    // default to enabled
    _enabledDictionary[identifier] = @(YES) ;

    // If it's built-in, we already have what we need, and if it isn't...
    if (![builtinToolbarItems containsObject:identifier]) {
        NSMutableDictionary *toolbarItem     = [[NSMutableDictionary alloc] init] ;
        BOOL isGroup = NO ;

        lua_pushnil(L);  /* first key */
        while (lua_next(L, idx) != 0) { /* uses 'key' (at index -2) and 'value' (at index -1) */
            if (lua_type(L, -2) == LUA_TSTRING) {
                NSString *keyName = [skin toNSObjectAtIndex:-2] ;
//                 NSLog(@"%@:%@", identifier, keyName) ;
                if (![keysToKeepFromDefinitionDictionary containsObject:keyName]) {
                    if (lua_type(L, -1) != LUA_TFUNCTION) {
                        toolbarItem[keyName] = [skin toNSObjectAtIndex:-1] ;
                        if ([keyName isEqualToString:@"groupMembers"]) isGroup = YES ;
                    } else if ([keyName isEqualToString:@"fn"]) {
                        lua_pushvalue(L, -1) ;
                        _fnRefDictionary[identifier] = @([skin luaRef:refTable]) ;
                    }
                }
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s:non-string keys not allowed for toolbar item %@ definition", USERDATA_TB_TAG, identifier]] ;
                lua_pop(L, 2) ;
                return NO ;
            }
            /* removes 'value'; keeps 'key' for next iteration */
            lua_pop(L, 1);
        }

        // groups are allowed to not have a label, though they can
        if (!toolbarItem[@"label"] && !isGroup) toolbarItem[@"label"] = identifier ;
        if (selectable) [_selectableIdentifiers addObject:identifier] ;
        _itemDefDictionary[identifier] = toolbarItem ;
    }
    // by adjusting _allowedIdentifiers out here, we allow builtin items, even if we don't exactly
    // advertise them, plus we may add support for duplicate id's at some point if someone comes up with
    // a reason...
    if (![_allowedIdentifiers containsObject:identifier] && allowedAlone)
        [_allowedIdentifiers addObject:identifier] ;
    if (included)
        [_defaultIdentifiers addObject:identifier] ;

    return YES ;
}

- (void)fillinNewToolbarItem:(NSToolbarItem *)item {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    [self updateToolbarItem:item
             withDictionary:_itemDefDictionary[item.itemIdentifier]
                    inGroup:NO
                  withState:skin.L] ;
}

- (void)updateToolbarItem:(NSToolbarItem *)item
           withDictionary:(NSMutableDictionary *)itemDefinition withState:(lua_State *)L {
    [self updateToolbarItem:item
             withDictionary:itemDefinition
                    inGroup:NO
                  withState:L] ;
}

// TODO ? separate validation of data from apply to live/create new item ? may be cleaner...

- (void)updateToolbarItem:(NSToolbarItem *)item
           withDictionary:(NSMutableDictionary *)itemDefinition
                  inGroup:(BOOL)inGroup
                withState:(lua_State *)L {

    LuaSkin               *skin       = [LuaSkin sharedWithState:L] ;
    HSToolbarSearchField *itemView   = (HSToolbarSearchField *)item.view ;
    NSString              *identifier = item.itemIdentifier ;

    // handle empty update tables
    if ([itemDefinition count] == 0) {
        if (!item.label) item.label = identifier ;
        return ;
    }

    // need to take care of this first in case we need to create the searchfield view for later items...
    id keyValue = itemDefinition[@"searchfield"] ;
    if (keyValue) {
        if ([keyValue isKindOfClass:[NSNumber class]] && !strcmp(boolEncodingType, [keyValue objCType])) {
            if ([keyValue boolValue]) {
                if (![itemView isKindOfClass:[HSToolbarSearchField class]]) {
                    if (!itemView) {
                        itemView             = [[HSToolbarSearchField alloc] init];
                        itemView.toolbarItem = item ;
                        itemView.target      = self ;
                        itemView.action      = @selector(performCallback:) ;
                        item.view            = itemView ;
                        if (!inGroup) {
                            item.minSize = itemView.frame.size ;
                            item.maxSize = itemView.frame.size ;
                        }
                    } else {
                        [skin logWarn:[NSString stringWithFormat:@"%s:view for toolbar item %@ is not our searchfield... cowardly avoiding replacement", USERDATA_TB_TAG, identifier]] ;
                    }
                } // else it already exists, so don't re-create it
            } else {
                if (itemView) {
                    if (![itemView isKindOfClass:[HSToolbarSearchField class]]) {
                        [skin logWarn:[NSString stringWithFormat:@"%s:view for toolbar item %@ is not our searchfield... cowardly avoiding removal", USERDATA_TB_TAG, identifier]] ;
                    } else {
                        item.view = nil ;
                        itemView  = nil ;
                    }
                } // else it doesn't exist, so nothing to remove
            }

        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:searchfield for %@ must be a boolean", USERDATA_TB_TAG, identifier]] ;
            [itemDefinition removeObjectForKey:@"searchfield"] ;
        }
    }

    keyValue = itemDefinition[@"searchPredefinedMenuTitle"] ;
    if (keyValue) {
        if ([keyValue isKindOfClass:[NSString class]] || ([keyValue isKindOfClass:[NSNumber class]] && !strcmp(boolEncodingType, [keyValue objCType]))) {
        // make sure searchPredefinedSearches is in this dictionary since we need to recreate it anyways
            if ((itemDefinition != _itemDefDictionary[identifier]) && !itemDefinition[@"searchPredefinedSearches"]) {
                itemDefinition[@"searchPredefinedSearches"] = _itemDefDictionary[identifier][@"searchPredefinedSearches"] ;
            }
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:searchPredefinedMenuTitle for %@ must be a string or a boolean", USERDATA_TB_TAG, identifier]] ;
            [itemDefinition removeObjectForKey:@"searchPredefinedMenuTitle"] ;
        }
    }

    for (NSString *keyName in [itemDefinition allKeys]) {
        keyValue = itemDefinition[keyName] ;

        if ([keyName isEqualToString:@"enable"]) {
            if ([keyValue isKindOfClass:[NSNumber class]] && !strcmp(boolEncodingType, [keyValue objCType])) {
                _enabledDictionary[identifier] = itemDefinition[keyName] ;
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s:%@ for %@ must be a boolean", USERDATA_TB_TAG, keyName, identifier]] ;
                [itemDefinition removeObjectForKey:keyName] ;
            }
        } else if ([keyName isEqualToString:@"fn"]) {
            if (_fnRefDictionary[identifier] && [_fnRefDictionary[identifier] intValue] != LUA_NOREF) {
                [skin luaUnref:refTable ref:[_fnRefDictionary[identifier] intValue]] ;
            }
            [skin pushLuaRef:refTable ref:[itemDefinition[keyName] intValue]] ;
            _fnRefDictionary[identifier] = @([skin luaRef:refTable]) ;
        } else if ([keyName isEqualToString:@"label"]) {
            if ([keyValue isKindOfClass:[NSString class]]) {
// for grouped sets, the palette label *must* be set or unset in sync with label, otherwise it only shows some of the individual labels... so simpler to just forget that there are actually two labels. Very few will likely care/notice anyways.
                    item.label        = keyValue ;
                    item.paletteLabel = keyValue ;
            } else {
                if ([keyValue isKindOfClass:[NSNumber class]] && ![keyValue boolValue]) {
                    if ([item isKindOfClass:[NSToolbarItemGroup class]]) {
// this is the only way to switch a grouped set's individual labels back on after turning them off by setting a group label...
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
                        ((NSToolbarItemGroup *)item).label        = nil ;
                        ((NSToolbarItemGroup *)item).paletteLabel = nil ;
#pragma clang diagnostic pop
                    } else {
                        item.label        = @"" ;
                        item.paletteLabel = identifier ;
                    }
                } else {
                    [skin logWarn:[NSString stringWithFormat:@"%s:%@ for %@ must be a string, or false to clear", USERDATA_TB_TAG, keyName, identifier]] ;
                }
                [itemDefinition removeObjectForKey:keyName] ;
            }
        } else if ([keyName isEqualToString:@"tooltip"]) {
            if ([keyValue isKindOfClass:[NSString class]]) {
                item.toolTip = keyValue ;
            } else {
                if ([keyValue isKindOfClass:[NSNumber class]] && ![keyValue boolValue]) {
                    item.toolTip = nil ;
                } else {
                    [skin logWarn:[NSString stringWithFormat:@"%s:%@ for %@ must be a string, or false to clear", USERDATA_TB_TAG, keyName, identifier]] ;
                }
                [itemDefinition removeObjectForKey:keyName] ;
            }
        } else if ([keyName isEqualToString:@"priority"]) {
            if ([keyValue isKindOfClass:[NSNumber class]]) {
                item.visibilityPriority = [keyValue intValue] ;
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s:%@ for %@ must be an integer", USERDATA_TB_TAG, keyName, identifier]] ;
                [itemDefinition removeObjectForKey:keyName] ;
            }
        } else if ([keyName isEqualToString:@"tag"]) {
            if ([keyValue isKindOfClass:[NSNumber class]]) {
                item.tag = [keyValue intValue] ;
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s:%@ for %@ must be an integer", USERDATA_TB_TAG, keyName, identifier]] ;
                [itemDefinition removeObjectForKey:keyName] ;
            }
        } else if ([keyName isEqualToString:@"image"]) {
            if ([keyValue isKindOfClass:[NSImage class]]) {
                item.image = keyValue ;
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s:%@ for %@ must be an hs.image obejct", USERDATA_TB_TAG, keyName, identifier]] ;
                [itemDefinition removeObjectForKey:keyName] ;
            }

        } else if ([keyName isEqualToString:@"groupMembers"]) {
            if ([item isKindOfClass:[NSToolbarItemGroup class]] && !inGroup) {
                if ([keyValue isKindOfClass:[NSArray class]]) {
                    BOOL allGood = YES ;
                    for (NSString *lineItem in (NSArray *)keyValue) {
                        if (![lineItem isKindOfClass:[NSString class]]) {
                            allGood = NO ;
                            break ;
                        }
                    }
                    if (allGood) {

                        NSMutableArray *newSubitems    = [[NSMutableArray alloc] init] ;
                        NSArray        *oldSubitems    = ((NSToolbarItemGroup *)item).subitems ? ((NSToolbarItemGroup *)item).subitems : @[ ] ;
                        NSMutableArray *updateViews    = [[NSMutableArray alloc] init] ;

                        for (NSString *memberIdentifier in (NSArray *)keyValue) {
                            NSUInteger existingIndex = [oldSubitems indexOfObjectPassingTest:^(NSToolbarItem *obj, __unused NSUInteger idx, __unused BOOL *stop) {
                                return [obj.itemIdentifier isEqualToString:memberIdentifier] ;
                            }] ;
                            NSToolbarItem *memberItem = (existingIndex != NSNotFound) ? oldSubitems[existingIndex] : [[NSToolbarItem alloc] initWithItemIdentifier:memberIdentifier] ;

                            if (existingIndex == NSNotFound) {
                                memberItem.target  = self ;
                                memberItem.action  = @selector(performCallback:) ;
                                memberItem.enabled = [_enabledDictionary[memberIdentifier] boolValue] ;
                                [self updateToolbarItem:memberItem withDictionary:_itemDefDictionary[memberIdentifier] inGroup:YES withState:L] ;
                                // See NSToolbarItemGroup is dumb below
                                if ([memberItem.view isKindOfClass:[HSToolbarSearchField class]]) {
                                    [updateViews addObject:memberItem] ;
                                }
                            }
                            [newSubitems addObject:memberItem] ;
                        }
                        ((NSToolbarItemGroup *)item).subitems = newSubitems ;

                        // NSToolbarItemGroup is dumb...
                        // see http://stackoverflow.com/questions/15949835/nstoolbaritemgroup-doesnt-work
                        //
                        // size of a sub-item's view needs to be adjusted *after* adding them to the group...
                        for (NSToolbarItem* tmpItem in updateViews) {
                            NSDictionary          *tmpItemDictionary = _itemDefDictionary[tmpItem.itemIdentifier] ;
                            HSToolbarSearchField *searchView        = (HSToolbarSearchField *)tmpItem.view ;
                            NSRect                 searchFieldFrame  = searchView.frame ;

                            if (tmpItemDictionary[@"searchWidth"]) {
                                searchFieldFrame.size.width = [tmpItemDictionary[@"searchWidth"] doubleValue] ;
                            }
                            tmpItem.minSize = searchFieldFrame.size ;
                            tmpItem.maxSize = searchFieldFrame.size ;
                        }

                        // *and* it internally calculates the itemGroup's size wrong
                        NSSize minSize = NSZeroSize;
                        NSSize maxSize = NSZeroSize;
                        for (NSToolbarItem* tmpItem in ((NSToolbarItemGroup *)item).subitems) {
                            minSize.width += tmpItem.minSize.width;
                            minSize.height = fmax(minSize.height, tmpItem.minSize.height);
                            maxSize.width += tmpItem.maxSize.width;
                            maxSize.height = fmax(maxSize.height, tmpItem.maxSize.height);
                        }
                        item.minSize = minSize;
                        item.maxSize = maxSize;
                    } else {
                        [skin logWarn:[NSString stringWithFormat:@"%s:%@ for %@ must be an array of strings", USERDATA_TB_TAG, keyName, identifier]] ;
                        [itemDefinition removeObjectForKey:keyName] ;
                    }
                } else {
                    [skin logWarn:[NSString stringWithFormat:@"%s:%@ for %@ must be an array", USERDATA_TB_TAG, keyName, identifier]] ;
                }
            } else {
                if (inGroup) {
                    [skin logWarn:[NSString stringWithFormat:@"%s:%@ is in a group and cannot contain group members. Remove item from it's group first.", USERDATA_TB_TAG, identifier]] ;
                } else {
                    [skin logWarn:[NSString stringWithFormat:@"%s:cannot change currently visible toolbar item %@ type. Remove item from toolbar first.", USERDATA_TB_TAG, identifier]] ;
                }
                [itemDefinition removeObjectForKey:keyName] ;
            }
        } else if ([keyName isEqualToString:@"searchWidth"] && [itemView isKindOfClass:[HSToolbarSearchField class]]) {
            if ([keyValue isKindOfClass:[NSNumber class]]) {
                if (!inGroup) {
                    NSRect fieldFrame     = itemView.frame ;
                    fieldFrame.size.width = [keyValue doubleValue] ;
                    item.minSize          = fieldFrame.size ;
                    item.maxSize          = fieldFrame.size ;
                }
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s:%@ for %@ must be a number", USERDATA_TB_TAG, keyName, identifier]] ;
                [itemDefinition removeObjectForKey:keyName] ;
            }
        } else if ([keyName isEqualToString:@"searchReleaseFocusOnCallback"] && [itemView isKindOfClass:[HSToolbarSearchField class]]) {
            if ([keyValue isKindOfClass:[NSNumber class]] && !strcmp(boolEncodingType, [keyValue objCType])) {
                itemView.releaseOnCallback = [keyValue boolValue] ;
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s:%@ for %@ must be a boolean", USERDATA_TB_TAG, keyName, identifier]] ;
                [itemDefinition removeObjectForKey:keyName] ;
            }
        } else if ([keyName isEqualToString:@"searchText"] && [itemView isKindOfClass:[HSToolbarSearchField class]]) {
            if ([keyValue isKindOfClass:[NSString class]]) {
                itemView.stringValue = keyValue ;
            } else if ([keyValue isKindOfClass:[NSNumber class]]) {
                itemView.stringValue = [keyValue stringValue] ;
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s:%@ for %@ must be a string", USERDATA_TB_TAG, keyName, identifier]] ;
                [itemDefinition removeObjectForKey:keyName] ;
            }
        } else if ([keyName isEqualToString:@"searchPredefinedSearches"]  && [itemView isKindOfClass:[HSToolbarSearchField class]]) {
            if ([keyValue isKindOfClass:[NSArray class]]) {
                BOOL allGood = YES ;
                for (NSString *lineItem in (NSArray *)keyValue) {
                    if (![lineItem isKindOfClass:[NSString class]]) {
                        allGood = NO ;
                        break ;
                    }
                }
                if (allGood) {
                    NSMenu *searchMenu = createCoreSearchFieldMenu() ;
                    NSMenu *predefinedSearchMenu = [[NSMenu alloc] initWithTitle:@"Predefined Search Menu"] ;
                    for (NSString *menuItemText in (NSArray *)keyValue) {
                        NSMenuItem* newMenuItem = [[NSMenuItem alloc] initWithTitle:menuItemText
                                                                             action:@selector(searchCallback:)
                                                                      keyEquivalent:@""] ;
                        newMenuItem.target = itemView ;
                        [predefinedSearchMenu addItem:newMenuItem];
                    }

                    NSString *menuName = @"Predefined Searches" ;
                    // here we need to check both the formal definition and the (possibly different) itemDefinition for the key, since we need it whether this is a create or a modify
                    id checkForTitle = itemDefinition[@"searchPredefinedMenuTitle"] ? itemDefinition[@"searchPredefinedMenuTitle"] : _itemDefDictionary[identifier][@"searchPredefinedMenuTitle"] ;

                    if (checkForTitle) {
                        if ([checkForTitle isKindOfClass:[NSNumber class]] && !strcmp(boolEncodingType, [checkForTitle objCType])) {
                            if (![checkForTitle boolValue]) {
                                menuName = nil ;
                            }
                        } else if ([checkForTitle isKindOfClass:[NSString class]]) {
                            menuName = checkForTitle ;
                        }
                    }

                    if (menuName) {
                        NSMenuItem *predefinedSearches = [[NSMenuItem alloc] initWithTitle:menuName action:nil keyEquivalent:@""] ;
                        predefinedSearches.submenu     = predefinedSearchMenu ;
                        [searchMenu insertItem:predefinedSearches atIndex:0] ;
                        [searchMenu insertItem:[NSMenuItem separatorItem] atIndex:1];
                    } else {
                        searchMenu = predefinedSearchMenu ;
                    }
                    ((NSSearchFieldCell *)itemView.cell).searchMenuTemplate = searchMenu ;
                } else {
                    [skin logWarn:[NSString stringWithFormat:@"%s:%@ for %@ must be an array of strings", USERDATA_TB_TAG, keyName, identifier]] ;
                    [itemDefinition removeObjectForKey:keyName] ;
                }
            } else {
                if ([keyValue isKindOfClass:[NSNumber class]] && ![keyValue boolValue]) {
                    NSMenu *searchMenu = createCoreSearchFieldMenu() ;
                    ((NSSearchFieldCell *)itemView.cell).searchMenuTemplate = searchMenu ;
                } else {
                    [skin logWarn:[NSString stringWithFormat:@"%s:%@ for %@ must be an array, or false to remove", USERDATA_TB_TAG, keyName, identifier]] ;
                }
                [itemDefinition removeObjectForKey:keyName] ;
            }
        } else if ([keyName isEqualToString:@"searchHistoryLimit"] && [itemView isKindOfClass:[HSToolbarSearchField class]]) {
            if ([keyValue isKindOfClass:[NSNumber class]]) {
                ((NSSearchFieldCell *)itemView.cell).maximumRecents = [keyValue intValue] ;
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s:%@ for %@ must be an integer", USERDATA_TB_TAG, keyName, identifier]] ;
                [itemDefinition removeObjectForKey:keyName] ;
            }
        } else if ([keyName isEqualToString:@"searchHistory"] && [itemView isKindOfClass:[HSToolbarSearchField class]]) {
            if ([keyValue isKindOfClass:[NSArray class]]) {
                BOOL allGood = YES ;
                for (NSString *lineItem in (NSArray *)keyValue) {
                    if (![lineItem isKindOfClass:[NSString class]]) {
                        allGood = NO ;
                        break ;
                    }
                }
                if (allGood) {
                    ((NSSearchFieldCell *)itemView.cell).recentSearches = keyValue ;
                } else {
                    [skin logWarn:[NSString stringWithFormat:@"%s:%@ for %@ must be an array of strings", USERDATA_TB_TAG, keyName, identifier]] ;
                    [itemDefinition removeObjectForKey:keyName] ;
                }
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s:%@ for %@ must be an array", USERDATA_TB_TAG, keyName, identifier]] ;
                [itemDefinition removeObjectForKey:keyName] ;
            }
        } else if ([keyName isEqualToString:@"searchHistoryAutosaveName"] && [itemView isKindOfClass:[HSToolbarSearchField class]]) {
            if ([keyValue isKindOfClass:[NSString class]]) {
                ((NSSearchFieldCell *)itemView.cell).recentsAutosaveName = keyValue ;
                [(NSSearchFieldCell *)itemView.cell recentSearches] ; // force load to populate menu
            } else if ([keyValue isKindOfClass:[NSNumber class]]) {
                ((NSSearchFieldCell *)itemView.cell).recentsAutosaveName = [keyValue stringValue] ;
                [(NSSearchFieldCell *)itemView.cell recentSearches] ; // force load to populate menu
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s:%@ for %@ must be a string", USERDATA_TB_TAG, keyName, identifier]] ;
                [itemDefinition removeObjectForKey:keyName] ;
            }

        // handled before loop, but we don't want to clear it, either
        } else if (![keyName isEqualToString:@"searchfield"] && ![keyName isEqualToString:@"searchPredefinedMenuTitle"]) {
            [skin logVerbose:[NSString stringWithFormat:@"%s:%@ is not a valid field for %@; ignoring", USERDATA_TB_TAG, keyName, identifier]] ;
            [itemDefinition removeObjectForKey:keyName] ;
        }
    }
    // if we weren't send the actual item's full dictionary, then this must be an update... update the item's full definition so that it's available for the configuration panel and for duplicate toolbars
    if (_itemDefDictionary[identifier] != itemDefinition) {
        [_itemDefDictionary[identifier] addEntriesFromDictionary:itemDefinition] ;
    }
}

#pragma mark - NSToolbarDelegate stuff

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)flag {
    NSDictionary  *itemDefinition = _itemDefDictionary[identifier] ;
    NSToolbarItem *toolbarItem ;

    if (itemDefinition) {
        if (itemDefinition[@"groupMembers"] && [itemDefinition[@"groupMembers"] isKindOfClass:[NSArray class]]) {
            toolbarItem = (NSToolbarItem *)[[NSToolbarItemGroup alloc] initWithItemIdentifier:identifier] ;
        } else {
            toolbarItem         = [[NSToolbarItem alloc] initWithItemIdentifier:identifier] ;
            toolbarItem.target  = toolbar ;
            toolbarItem.action  = @selector(performCallback:) ;
        }
        toolbarItem.enabled = flag ? [self validateToolbarItem:toolbarItem] : YES ;
        [self fillinNewToolbarItem:toolbarItem] ;
    } else {
        // may happen on a reload if toolbar autosave contains id's that were added after the toolbar was created but haven't been created yet since the reload
        [LuaSkin logInfo:[NSString stringWithFormat:@"%s:toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar: invoked with non-existent identifier:%@", USERDATA_TB_TAG, identifier]] ;
    }
    return toolbarItem ;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(__unused NSToolbar *)toolbar  {
//     [LuaSkin logWarn:@"in toolbarAllowedItemIdentifiers"] ;
    return [_allowedIdentifiers array] ;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(__unused NSToolbar *)toolbar {
//     [LuaSkin logWarn:@"in toolbarDefaultItemIdentifiers"] ;
    return [_defaultIdentifiers array] ;
}

- (NSArray *)toolbarSelectableItemIdentifiers:(__unused NSToolbar *)toolbar {
//     [LuaSkin logWarn:@"in toolbarSelectableItemIdentifiers"] ;
    return [_selectableIdentifiers array] ;
}

- (void)toolbarWillAddItem:(NSNotification *)notification {
    if (_notifyToolbarChanges && (_callbackRef != LUA_NOREF)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.callbackRef != LUA_NOREF) {
                NSWindow  *ourWindow = self.windowUsingToolbar ;
                LuaSkin   *skin      = [LuaSkin sharedWithState:NULL] ;
                lua_State *L         = [skin L] ;
                _lua_stackguard_entry(L);
                [skin pushLuaRef:refTable ref:self.callbackRef] ;
                [skin pushNSObject:self] ;
                if (ourWindow) {
                    if ([ourWindow isEqualTo:[[MJConsoleWindowController singleton] window]]) {
                        lua_pushstring(L, "console") ;
                    } else if (ourWindow.windowController) { // hs.chooser
                        [skin pushNSObject:ourWindow.windowController withOptions:LS_NSDescribeUnknownTypes] ;
                    } else {
                        [skin pushNSObject:ourWindow withOptions:LS_NSDescribeUnknownTypes] ;
                    }
                } else {
                    // shouldn't be possible, but just in case...
                    lua_pushstring(L, "** no window attached") ;
                }
                [skin pushNSObject:[notification.userInfo[@"item"] itemIdentifier]] ;
                lua_pushstring(L, "add") ;
                [skin protectedCallAndError:[NSString stringWithFormat:@"hs.webview.toolbar toolbar item addition callback (%@)", [notification.userInfo[@"item"] itemIdentifier]] nargs:4 nresults:0];
                _lua_stackguard_exit(L);
            }
        }) ;
    }
}

- (void)toolbarDidRemoveItem:(NSNotification *)notification {
    if (_notifyToolbarChanges && (_callbackRef != LUA_NOREF)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.callbackRef != LUA_NOREF) {
                NSWindow  *ourWindow = self.windowUsingToolbar ;
                LuaSkin   *skin      = [LuaSkin sharedWithState:NULL] ;
                lua_State *L         = [skin L] ;
                _lua_stackguard_entry(L);
                [skin pushLuaRef:refTable ref:self.callbackRef] ;
                [skin pushNSObject:self] ;
                if (ourWindow) {
                    if ([ourWindow isEqualTo:[[MJConsoleWindowController singleton] window]]) {
                        lua_pushstring(L, "console") ;
                    } else if (ourWindow.windowController) { // hs.chooser
                        [skin pushNSObject:ourWindow.windowController withOptions:LS_NSDescribeUnknownTypes] ;
                    } else {
                        [skin pushNSObject:ourWindow withOptions:LS_NSDescribeUnknownTypes] ;
                    }
                } else {
                    // shouldn't be possible, but just in case...
                    lua_pushstring(L, "** no window attached") ;
                }
                [skin pushNSObject:[notification.userInfo[@"item"] itemIdentifier]] ;
                lua_pushstring(L, "remove") ;
                [skin protectedCallAndError:[NSString stringWithFormat:@"hs.webview.toolbar toolbar item removal callback (%@)", [notification.userInfo[@"item"] itemIdentifier]] nargs:4 nresults:0];
                _lua_stackguard_exit(L);
            }
        }) ;
    }
}

@end

@implementation HSToolbarSearchField
- (instancetype)init {
    self = [super init] ;
    if (self) {
        self.sendsWholeSearchString = YES ;
        self.sendsSearchStringImmediately = NO ;
        [self sizeToFit];

        _toolbarItem = nil ;
        _releaseOnCallback = NO ;

        ((NSSearchFieldCell *)self.cell).searchMenuTemplate = createCoreSearchFieldMenu();
    }
    return self ;
}

- (void)searchCallback:(NSMenuItem *)sender {
    self.stringValue = sender.title ;
    [(HSToolbar *)_toolbarItem.toolbar performCallback:self] ;
}

@end

#pragma mark - Module Functions

/// hs.webview.toolbar.new(toolbarName, [toolbarTable]) -> toolbarObject
/// Constructor
/// Creates a new toolbar for a webview, chooser, or the console.
///
/// Parameters:
///  * toolbarName  - a string specifying the name for this toolbar
///  * toolbarTable - an optional table describing possible items for the toolbar
///
/// Returns:
///  * a toolbarObject
///
/// Notes:
///  * Toolbar names must be unique, but a toolbar may be copied with [hs.webview.toolbar:copy](#copy) if you wish to attach it to multiple windows (webview, chooser, or console).
///  * See [hs.webview.toolbar:addItems](#addItems) for a description of the format for `toolbarTable`

static int newHSToolbar(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *identifier = [skin toNSObjectAtIndex:1] ;

    int idx = (lua_gettop(L) == 2) ? 2 : LUA_NOREF ;

    if (![identifiersInUse containsObject:identifier]) {
        HSToolbar *toolbar = [[HSToolbar alloc] initWithIdentifier:identifier
                                                    itemTableIndex:idx
                                                          andState:L] ;
        if (toolbar) {
            [skin pushNSObject:toolbar] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        return luaL_argerror(L, 1, "identifier already in use") ;
    }
    return 1 ;
}

/// hs.webview.toolbar.uniqueName(toolbarName) -> boolean
/// Function
/// Checks to see is a toolbar name is already in use
///
/// Parameters:
///  * toolbarName  - a string specifying the name of a toolbar
///
/// Returns:
///  * `true` if the name is unique otherwise `false`
static int uniqueName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *identifier = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, ![identifiersInUse containsObject:identifier]);
    return 1 ;
}

/// hs.webview.toolbar.attachToolbar([obj1], [obj2]) -> obj1
/// Function
/// Get or attach/detach a toolbar to the webview, chooser, or console.
///
/// Parameters:
///  * obj1 - An optional toolbarObject
///  * obj2 - An optional toolbarObject
///   * if no arguments are present, this function returns the current toolbarObject for the Hammerspoon console, or nil if one is not attached.
///   * if one argument is provided and it is a toolbarObject or nil, this function will attach or detach a toolbarObject to/from the Hammerspoon console.
///   * if one argument is provided and it is an hs.webview or hs.chooser object, this function will return the current toolbarObject for the object, or nil if one is not attached.
///   * if two arguments are provided and the first is an hs.webview or hs.chooser object and the second is a toolbarObject or nil, this function will attach or detach a toolbarObject to/from the object.
///
/// Returns:
///  * if the function is used to attach/detach a toolbar, then the first object provided (the target) will be returned ; if this function is used to get the current toolbar object for a webview, chooser, or console, then the toolbarObject or nil will be returned.
///
/// Notes:
///  * This function is not expected to be used directly (though it can be) -- it is added to the `hs.webview` and `hs.chooser` object metatables so that it may be invoked as `hs.webview:attachedToolbar([toolbarObject | nil])`/`hs.chooser:attachedToolbar([toolbarObject | nil])` and to the `hs.console` module so that it may be invoked as `hs.console.toolbar([toolbarObject | nil])`.
///
///  * If the toolbar is currently attached to another window when this function is called, it will be detached from the original window and attached to the new one specified by this function.
static int attachToolbar(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSWindow  *theWindow ;
    HSToolbar *newToolbar ;
    BOOL      setToolbar = YES ;
    BOOL      isChooser  = NO ;

// hs.console

    if (lua_gettop(L) == 0) {
        theWindow  = [[MJConsoleWindowController singleton] window];
        newToolbar = nil ;
        setToolbar = NO ;
    } else if (lua_gettop(L) == 1 && (lua_type(L, 1) == LUA_TNIL)) {
        theWindow  = [[MJConsoleWindowController singleton] window];
        newToolbar = nil ;
        setToolbar = YES ;
    } else if (lua_gettop(L) == 1 && (lua_type(L, 1) == LUA_TUSERDATA) && luaL_testudata(L, 1, USERDATA_TB_TAG)) {
        theWindow  = [[MJConsoleWindowController singleton] window];
        newToolbar = [skin toNSObjectAtIndex:1] ;
        setToolbar = YES ;

// hs.webview

    } else if (lua_gettop(L) == 1 && (lua_type(L, 1) == LUA_TUSERDATA) && luaL_testudata(L, 1, "hs.webview")) {
        theWindow = get_objectFromUserdata(__bridge NSWindow, L, 1, "hs.webview") ;
        newToolbar = nil ;
        setToolbar = NO ;
    } else if (lua_gettop(L) == 2 && (lua_type(L, 1) == LUA_TUSERDATA) && luaL_testudata(L, 1, "hs.webview") && (lua_type(L, 2) == LUA_TNIL)) {
        theWindow = get_objectFromUserdata(__bridge NSWindow, L, 1, "hs.webview") ;
        newToolbar = nil ;
        setToolbar = YES ;
    } else if (lua_gettop(L) == 2 && lua_type(L, 1) == LUA_TUSERDATA && luaL_testudata(L, 1, "hs.webview") && (lua_type(L, 2) == LUA_TUSERDATA) && luaL_testudata(L, 2, USERDATA_TB_TAG)) {
        theWindow = get_objectFromUserdata(__bridge NSWindow, L, 1, "hs.webview") ;
        newToolbar = [skin toNSObjectAtIndex:2] ;
        setToolbar = YES ;

// hs.chooser

    } else if (lua_gettop(L) == 1 && (lua_type(L, 1) == LUA_TUSERDATA) && luaL_testudata(L, 1, "hs.chooser")) {
        NSWindowController *theController = get_objectFromUserdata(__bridge NSWindowController, L, 1, "hs.chooser") ;
        theWindow = theController.window ;
        newToolbar = nil ;
        setToolbar = NO ;
        isChooser = YES ;
    } else if (lua_gettop(L) == 2 && (lua_type(L, 1) == LUA_TUSERDATA) && luaL_testudata(L, 1, "hs.chooser") && (lua_type(L, 2) == LUA_TNIL)) {
        NSWindowController *theController = get_objectFromUserdata(__bridge NSWindowController, L, 1, "hs.chooser") ;
        theWindow = theController.window ;
        newToolbar = nil ;
        setToolbar = YES ;
        isChooser = YES ;
    } else if (lua_gettop(L) == 2 && lua_type(L, 1) == LUA_TUSERDATA && luaL_testudata(L, 1, "hs.chooser") && (lua_type(L, 2) == LUA_TUSERDATA) && luaL_testudata(L, 2, USERDATA_TB_TAG)) {
        NSWindowController *theController = get_objectFromUserdata(__bridge NSWindowController, L, 1, "hs.chooser") ;
        theWindow = theController.window ;
        newToolbar = [skin toNSObjectAtIndex:2] ;
        setToolbar = YES ;
        isChooser = YES ;

    } else {
        return luaL_error(L, "%s:attachToolbar requires an optional window target object and an %s object or nil", USERDATA_TB_TAG, USERDATA_TB_TAG) ;
    }

    HSToolbar *oldToolbar = (HSToolbar *)theWindow.toolbar ;
    if (setToolbar) {
        if (oldToolbar) {
            oldToolbar.visible = NO ;
            theWindow.toolbar = nil ;
            if (isChooser) {
                theWindow.styleMask = NSWindowStyleMaskFullSizeContentView | NSWindowStyleMaskNonactivatingPanel ; // the default for chooser
                [theWindow setMovable: YES]; // the default for chooser, even though the user can't move it without a titlebar
            }
            if ([oldToolbar isKindOfClass:[HSToolbar class]]) oldToolbar.windowUsingToolbar = nil ;
        }
        if (newToolbar) {
            NSWindow *newTBWindow = newToolbar.windowUsingToolbar ;
            if (newTBWindow) newTBWindow.toolbar = nil ;
            if (isChooser) {
                theWindow.styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskNonactivatingPanel ; // only titled windows can have toolbars
                [theWindow setMovable: NO]; // chooser isn't user movable
            }
            theWindow.toolbar             = newToolbar ;
            newToolbar.windowUsingToolbar = theWindow ;
            newToolbar.visible            = YES ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        if ([oldToolbar isKindOfClass:[HSToolbar class]]) {
            [skin pushNSObject:oldToolbar] ;
        } else {
            // it's not ours, so don't know what to do with it
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

#pragma mark - Module Methods

/// hs.webview.toolbar:inTitleBar([state]) -> toolbarObject | boolean
/// Function
/// Get or set whether or not the toolbar appears in the containing window's titlebar, similar to Safari.
///
/// Parameters:
///  * `state` - an optional boolean specifying whether or not the toolbar should appear in the window's titlebar.
///
/// Returns:
///  * if a parameter is specified, returns the toolbar object, otherwise the current value.
///
/// Notes:
///  * When this value is true, the toolbar, when visible, will appear in the window's title bar similar to the toolbar as seen in applications like Safari.  In this state, the toolbar will set the display of the toolbar items to icons without labels, ignoring changes made with [hs.webview.toolbar:displayMode](#displayMode).
///
/// * This method is only valid when the toolbar is attached to a webview, chooser, or the console.
static int toolbar_inTitleBar(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSToolbar *toolbar   = [skin toNSObjectAtIndex:1] ;
    NSWindow  *theWindow = toolbar.windowUsingToolbar ;
    if (lua_gettop(L) == 1) {
        if (theWindow) {
            lua_pushboolean(L, theWindow.titleVisibility == NSWindowTitleHidden) ;
        } else {
            lua_pushboolean(L, NO) ;
        }
    } else {
        if (theWindow) {
            NSWindowTitleVisibility state = lua_toboolean(L, 2) ? NSWindowTitleHidden : NSWindowTitleVisible ;
            theWindow.titleVisibility = state ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:inTitleBar - requires the toolbar to be attached before using", USERDATA_TB_TAG]] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.webview.toolbar:isAttached() -> boolean
/// Method
/// Returns a boolean indicating whether or not the toolbar is currently attached to a window.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean indicating whether or not the toolbar is currently attached to a window.
static int isAttachedToWindow(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, [toolbar isAttachedToWindow]) ;
    return 1;
}

/// hs.webview.toolbar:copy() -> toolbarObject
/// Method
/// Returns a copy of the toolbar object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a copy of the toolbar which can be attached to another window (webview, chooser, or console).
static int copyToolbar(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TBREAK] ;
    HSToolbar *oldToolbar = [skin toNSObjectAtIndex:1] ;
    HSToolbar *newToolbar = [[HSToolbar alloc] initWithCopy:oldToolbar andState:L] ;
    if (newToolbar) {
        [skin pushNSObject:newToolbar] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.webview.toolbar:setCallback(fn) -> toolbarObject
/// Method
/// Sets or removes the global callback function for the toolbar.
///
/// Parameters:
///  * fn - a function to set as the global callback for the toolbar, or nil to remove the global callback.
///
///  The function should expect three (four, if the item is a `searchfield` or `notifyOnChange` is true) arguments and return none: the toolbar object, "console" or the webview/chooser object the toolbar is attached to, and the toolbar item identifier that was clicked.
/// Returns:
///  * the toolbar object.
///
/// Notes:
///  * the global callback function is invoked for a toolbar button item that does not have a specific function assigned directly to it.
///  * if [hs.webview.toolbar:notifyOnChange](#notifyOnChange) is set to true, then this callback function will also be invoked when a toolbar item is added or removed from the toolbar either programmatically with [hs.webview.toolbar:insertItem](#insertItem) and [hs.webview.toolbar:removeItem](#removeItem) or under user control with [hs.webview.toolbar:customizePanel](#customizePanel) and the callback function will receive a string of "add" or "remove" as a fourth argument.
static int setCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    // in either case, we need to remove an existing callback, so...
    toolbar.callbackRef = [skin luaUnref:refTable ref:toolbar.callbackRef] ;
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2) ;
        toolbar.callbackRef = [skin luaRef:refTable] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.webview.toolbar:savedSettings() -> table
/// Method
/// Returns a table containing the settings which will be saved for the toolbar if [hs.webview.toolbar:autosaves](#autosaves) is true.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing the toolbar settings
///
/// Notes:
///  * If the toolbar is set to autosave, then a user-defaults entry is created in org.hammerspoon.Hammerspoon domain with the key "NSToolbar Configuration XXX" where XXX is the toolbar identifier specified when the toolbar was created.
///  * This method is provided if you do not wish for changes to the toolbar to be autosaved for every change, but may wish to save it programmatically under specific conditions.
static int configurationDictionary(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[toolbar configurationDictionary]] ;
    return 1 ;
}

/// hs.webview.toolbar:separator([bool]) -> toolbarObject | bool
/// Method
/// Get or set whether or not the toolbar shows a separator between the toolbar and the main window contents.
///
/// Parameters:
///  * an optional boolean value to enable or disable the separator.
///
/// Returns:
///  * if an argument is provided, returns the toolbar object; otherwise returns the current value
static int showsBaselineSeparator(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) != 1) {
        toolbar.showsBaselineSeparator = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, [toolbar showsBaselineSeparator]) ;
    }
    return 1 ;
}

/// hs.webview.toolbar:visible([bool]) -> toolbarObject | bool
/// Method
/// Get or set whether or not the toolbar is currently visible in the window it is attached to.
///
/// Parameters:
///  * an optional boolean value to show or hide the toolbar.
///
/// Returns:
///  * if an argument is provided, returns the toolbar object; otherwise returns the current value
static int visible(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) != 1) {
        toolbar.visible = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, [toolbar isVisible]) ;
    }
    return 1 ;
}

/// hs.webview.toolbar:notifyOnChange([bool]) -> toolbarObject | bool
/// Method
/// Get or set whether or not the global callback function is invoked when a toolbar item is added or removed from the toolbar.
///
/// Parameters:
///  * an optional boolean value to enable or disable invoking the global callback for toolbar changes.
///
/// Returns:
///  * if an argument is provided, returns the toolbar object; otherwise returns the current value
static int notifyWhenToolbarChanges(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) != 1) {
        toolbar.notifyToolbarChanges = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, toolbar.notifyToolbarChanges) ;
    }
    return 1 ;
}

/// hs.webview.toolbar:insertItem(id, index) -> toolbarObject
/// Method
/// Insert or move the toolbar item to the index position specified
///
/// Parameters:
///  * id    - the string identifier of the toolbar item
///  * index - the numerical position where the toolbar item should be inserted/moved to.
///
/// Returns:
///  * the toolbar object
///
/// Notes:
///  * the toolbar position must be between 1 and the number of currently active toolbar items.
static int insertItemAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TSTRING, LS_TNUMBER, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    NSString  *identifier = [skin toNSObjectAtIndex:2] ;
    NSInteger index = luaL_checkinteger(L, 3) ;

    if (!toolbar.itemDefDictionary[identifier]) {
        return luaL_error(L, "toolbar item %s does not exist", [identifier UTF8String]) ;
    }
    if ((index < 1) || (index > (NSInteger)(toolbar.items.count + 1))) {
        return luaL_error(L, "index out of bounds") ;
    }
    if (![toolbar.allowedIdentifiers containsObject:identifier]) {
        return luaL_error(L, "%s is not allowed outside of its group", [identifier UTF8String]) ;
    }

    NSUInteger itemIndex = [[toolbar.items valueForKey:@"itemIdentifier"] indexOfObject:identifier] ;
    if ((itemIndex != NSNotFound) && ![toolbar.items[itemIndex] allowsDuplicatesInToolbar]) {
        [toolbar removeItemAtIndex:(NSInteger)itemIndex] ;
        // if we're moving it to the end, but already at the end, well, we just changed the index bounds...
        if (index > (NSInteger)(toolbar.items.count + 1)) index = index - 1 ;
    }

    [toolbar insertItemWithItemIdentifier:identifier atIndex:(index - 1)] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

// NOTE: wrapped and documented in toolbar.lua
static int removeItemAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TNUMBER, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    NSInteger index = luaL_checkinteger(L, 2) ;

    if ((index < 1) || (index > (NSInteger)(toolbar.items.count + 1))) {
        return luaL_error(L, "index out of bounds") ;
    }
    [toolbar removeItemAtIndex:(index - 1)] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.webview.toolbar:sizeMode([size]) -> toolbarObject
/// Method
/// Get or set the toolbar's size.
///
/// Parameters:
///  * size - an optional string to set the size of the toolbar to "default", "regular", or "small".
///
/// Returns:
///  * if an argument is provided, returns the toolbar object; otherwise returns the current value
static int sizeMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        NSString *size = [skin toNSObjectAtIndex:2] ;
        if ([size isEqualToString:@"default"]) {
            toolbar.sizeMode = NSToolbarSizeModeDefault ;
        } else if ([size isEqualToString:@"regular"]) {
            toolbar.sizeMode = NSToolbarSizeModeRegular ;
        } else if ([size isEqualToString:@"small"]) {
            toolbar.sizeMode = NSToolbarSizeModeSmall ;
        } else {
            return luaL_error(L, "invalid sizeMode:%s", [size UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        switch(toolbar.sizeMode) {
            case NSToolbarSizeModeDefault:
                [skin pushNSObject:@"default"] ;
                break ;
            case NSToolbarSizeModeRegular:
                [skin pushNSObject:@"regular"] ;
                break ;
            case NSToolbarSizeModeSmall:
                [skin pushNSObject:@"small"] ;
                break ;
// in case Apple extends this
            default:
                [skin pushNSObject:[NSString stringWithFormat:@"** unrecognized sizeMode (%tu)",
                                                              toolbar.sizeMode]] ;
                break ;
        }
    }
    return 1 ;
}

/// hs.webview.toolbar:displayMode([mode]) -> toolbarObject
/// Method
/// Get or set the toolbar's display mode.
///
/// Parameters:
///  * mode - an optional string to set the size of the toolbar to "default", "label", "icon", or "both".
///
/// Returns:
///  * if an argument is provided, returns the toolbar object; otherwise returns the current value
static int displayMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        NSString *type = [skin toNSObjectAtIndex:2] ;
        if ([type isEqualToString:@"default"]) {
            toolbar.displayMode = NSToolbarDisplayModeDefault ;
        } else if ([type isEqualToString:@"label"]) {
            toolbar.displayMode = NSToolbarDisplayModeLabelOnly ;
        } else if ([type isEqualToString:@"icon"]) {
            toolbar.displayMode = NSToolbarDisplayModeIconOnly ;
        } else if ([type isEqualToString:@"both"]) {
            toolbar.displayMode = NSToolbarDisplayModeIconAndLabel ;
        } else {
            return luaL_error(L, "invalid displayMode:%s", [type UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        switch(toolbar.displayMode) {
            case NSToolbarDisplayModeDefault:
                [skin pushNSObject:@"default"] ;
                break ;
            case NSToolbarDisplayModeLabelOnly:
                [skin pushNSObject:@"label"] ;
                break ;
            case NSToolbarDisplayModeIconOnly:
                [skin pushNSObject:@"icon"] ;
                break ;
            case NSToolbarDisplayModeIconAndLabel:
                [skin pushNSObject:@"both"] ;
                break ;
// in case Apple extends this
            default:
                [skin pushNSObject:[NSString stringWithFormat:@"** unrecognized displayMode (%tu)",
                                                              toolbar.displayMode]] ;
                break ;
        }
    }
    return 1 ;
}

/// hs.webview.toolbar:modifyItem(table) -> toolbarObject
/// Method
/// Modify the toolbar item specified by the "id" key in the table argument.
///
/// Parameters:
///  * a table containing an "id" key and the attributes to change for the toolbar item.
///
/// Returns:
///  * the toolbarObject
///
/// Notes:
///  * You cannot change a toolbar item's `id`
///  * For a list of the possible toolbar item attribute keys, see [hs.webview.toolbar:addItems](#addItems).
static int modifyToolbarItem(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TTABLE, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    NSString *identifier ;

    if (lua_getfield(L, 2, "id") == LUA_TSTRING) {
        identifier = [skin toNSObjectAtIndex:-1] ;
        if (!toolbar.itemDefDictionary[identifier]) {
            return luaL_error(L, "toolbar item %s does not exist", [identifier UTF8String]) ;
        }
        if ([builtinToolbarItems containsObject:identifier]) {
            return luaL_error(L, "cannot modify a built-in toolbar item definition") ;
        }
    } else {
        return luaL_error(L, "id must be present, and it must be a string") ;
    }
    lua_pop(L, 1) ;

    // not stored in itemDefinition, so handle specially
    if (lua_getfield(L, 2, "selectable") == LUA_TBOOLEAN) {
        if (lua_toboolean(L, -1)) {
            [toolbar.selectableIdentifiers addObject:identifier] ;
        } else {
            if ([toolbar.selectedItemIdentifier isEqualToString:identifier]) toolbar.selectedItemIdentifier = nil ;
            [toolbar.selectableIdentifiers removeObject:identifier] ;
        }
    }
    lua_pop(L, 1) ;
    if (lua_getfield(L, 2, "allowedAlone") == LUA_TBOOLEAN) {
        if (lua_toboolean(L, -1)) {
            [toolbar.allowedIdentifiers addObject:identifier] ;
        } else {
            [toolbar.allowedIdentifiers removeObject:identifier] ;
            [toolbar.defaultIdentifiers removeObject:identifier] ;
            NSUInteger itemIndex = [[toolbar.items valueForKey:@"itemIdentifier"] indexOfObject:identifier] ;
            if (itemIndex != NSNotFound) [toolbar removeItemAtIndex:(NSInteger)itemIndex] ;
        }
    }
    lua_pop(L, 1) ;
    if (lua_getfield(L, 2, "default") == LUA_TBOOLEAN) {
        if (lua_toboolean(L, -1)) {
            [toolbar.defaultIdentifiers addObject:identifier] ;
        } else {
            [toolbar.defaultIdentifiers removeObject:identifier] ;
        }
    }
    lua_pop(L, 1) ;

    NSMutableDictionary *newDict     = [[NSMutableDictionary alloc] init] ;
    lua_pushnil(L);  /* first key */
    while (lua_next(L, 2) != 0) { /* uses 'key' (at index -2) and 'value' (at index -1) */
        if (lua_type(L, -2) == LUA_TSTRING) {
            NSString *keyName = [skin toNSObjectAtIndex:-2] ;
            if (![keysToKeepFromDefinitionDictionary containsObject:keyName]) {
                if (lua_type(L, -1) != LUA_TFUNCTION) {
                    newDict[keyName] = [skin toNSObjectAtIndex:-1] ;
                } else if ([keyName isEqualToString:@"fn"]) {
                    lua_pushvalue(L, -1) ;
                    toolbar.fnRefDictionary[identifier] = @([skin luaRef:refTable]) ;
                }
            }
        } else {
            return luaL_error(L, "non-string keys not allowed in toolbar item definition %s ", [identifier UTF8String]) ;
        }
        /* removes 'value'; keeps 'key' for next iteration */
        lua_pop(L, 1);
    }

    if ([newDict count] > 0) {
        BOOL handled = NO ;
        if (toolbar.items) {
            for (NSToolbarItem *item in toolbar.items) {
                if ([item.itemIdentifier isEqualToString:identifier]) {
                    [toolbar updateToolbarItem:item withDictionary:newDict withState:L] ;
                    handled = YES ;
                } else if ([item isKindOfClass:[NSToolbarItemGroup class]]) {
                    for (NSToolbarItem *subItem in ((NSToolbarItemGroup *)item).subitems) {
                        if ([subItem.itemIdentifier isEqualToString:identifier]) {
                            [toolbar updateToolbarItem:subItem withDictionary:newDict withState:L] ;
                            handled = YES ;
                        }
                        if (handled) break ;
                    }
                }
            if (handled) break ;
            }
        }
        if (!handled) {
            if (lua_getfield(L, 2, "groupMembers") == LUA_TBOOLEAN && !lua_toboolean(L, -1)) {
                [newDict removeObjectForKey:@"groupMembers"] ;
                [(NSMutableDictionary *)toolbar.itemDefDictionary[identifier] removeObjectForKey:@"groupMembers"] ;
            }
            lua_pop(L, 1) ;
            [toolbar.itemDefDictionary[identifier] addEntriesFromDictionary:newDict] ;
        }
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

// NOTE: wrapped and documented in toolbar.lua
static int addToolbarItems(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TTABLE, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    lua_Integer count      = luaL_len(L, 2) ;
    lua_Integer index      = 0 ;
    BOOL        isGood     = YES ;

    while (isGood && (index < count)) {
        if (lua_rawgeti(L, 2, index + 1) == LUA_TTABLE) {
            isGood = [toolbar addToolbarDefinitionAtIndex:-1 withState:L] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:addItems - not a table at index %lld", USERDATA_TB_TAG, index + 1]] ;
            isGood = NO ;
        }
        lua_pop(L, 1) ;
        index++ ;
    }

    if (!isGood) {
        return luaL_error(L, "%s:addItems - malformed toolbar items encountered", USERDATA_TB_TAG) ;
    } else {
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.webview.toolbar:deleteItem(identifier) -> toolbarObject
/// Method
/// Deletes the toolbar item specified completely from the toolbar, removing it first, if the toolbar item is currently active.
///
/// Parameters:
///  * `identifier` - the toolbar item's identifier
///
/// Returns:
///  * the toolbar object
///
/// Notes:
///  * This method completely removes the toolbar item from the toolbar's definition dictionary, thus removing it from active use in the toolbar as well as removing it from the customization panel, if supported.  If you only want to remove a toolbar item from the active toolbar, consider [hs.webview.toolbar:removeItem](#removeItem).
static int deleteToolbarItem(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TSTRING, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    NSString *identifier = [skin toNSObjectAtIndex:2] ;

    if (!toolbar.itemDefDictionary[identifier]) {
        return luaL_error(L, "toolbar item %s does not exist", [identifier UTF8String]) ;
    }

    NSUInteger itemIndex = [[toolbar.items valueForKey:@"itemIdentifier"] indexOfObject:identifier] ;
    if (itemIndex != NSNotFound) {
        [toolbar removeItemAtIndex:(NSInteger)itemIndex] ;
    }
    [toolbar.itemDefDictionary removeObjectForKey:identifier] ;
    [toolbar.fnRefDictionary removeObjectForKey:identifier] ;
    [toolbar.enabledDictionary removeObjectForKey:identifier] ;
    [toolbar.allowedIdentifiers removeObject:identifier] ;
    [toolbar.defaultIdentifiers removeObject:identifier] ;
    [toolbar.selectableIdentifiers removeObject:identifier] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.webview.toolbar:itemDetails(id) -> table
/// Method
/// Returns a table containing details about the specified toolbar item
///
/// Parameters:
///  * id - a string identifier specifying the toolbar item
///
/// Returns:
///  * a table containing the toolbar item definition
///
/// Notes:
///  * For a list of the most of the possible toolbar item attribute keys, see [hs.webview.toolbar:addItems](#addItems).
///  * The table will also include `privateCallback` which will be a boolean indicating whether or not this toolbar item has a private callback function assigned (true) or uses the toolbar's general callback function (false).
///  * The returned table may also contain the following keys, if the item is currently assigned to a toolbar:
///    * `toolbar`  - the toolbar object the item belongs to
///    * `subItems` - if the toolbar item is actually a group, this will contain a table with basic information about the members of the group.  If you wish to get the full details for each sub-member, you may iterate on the identifiers provided in `groupMembers`.
static int detailsForItemIdentifier(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TSTRING, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    NSString *identifier = [skin toNSObjectAtIndex:2] ;

    if (!toolbar.itemDefDictionary[identifier]) {
        return luaL_error(L, "toolbar item %s does not exist", [identifier UTF8String]) ;
    }

    NSToolbarItem *ourItem ;
    for (NSToolbarItem *item in toolbar.items) {
        if ([identifier isEqualToString:[item itemIdentifier]]) {
            ourItem = item ;
            break ;
        } else if ([item isKindOfClass:[NSToolbarItemGroup class]]) {
            for (NSToolbarItem *subItem in [(NSToolbarItemGroup *)item subitems]) {
                if ([identifier isEqualToString:[subItem itemIdentifier]]) {
//                     [skin logDebug:@"details found an active subitem"] ;
                    ourItem = subItem ;
                    break ;
                }
            }
            if (ourItem) break ;
        }
    }
    if (!ourItem) ourItem = [toolbar.itemDefDictionary objectForKey:identifier] ;
    [skin pushNSObject:ourItem] ;
    lua_pushboolean(L, [toolbar.selectableIdentifiers containsObject:identifier]) ;
    lua_setfield(L, -2, "selectable") ;
    lua_pushboolean(L, [toolbar.defaultIdentifiers containsObject:identifier]) ;
    lua_setfield(L, -2, "default") ;
    lua_pushboolean(L, [toolbar.allowedIdentifiers containsObject:identifier]) ;
    lua_setfield(L, -2, "allowedAlone") ;
    NSNumber *fnRef = toolbar.fnRefDictionary[identifier] ;
    lua_pushboolean(L, fnRef && [fnRef integerValue] != LUA_NOREF) ;
    lua_setfield(L, -2, "privateCallback") ;
    if ([ourItem isKindOfClass:[NSToolbarItem class]]) {
        [skin pushNSObject:[(NSDictionary *)toolbar.itemDefDictionary[identifier] objectForKey:@"searchPredefinedMenuTitle"]] ;
        lua_setfield(L, -2, "searchPredefinedMenuTitle") ;
        [skin pushNSObject:[(NSDictionary *)toolbar.itemDefDictionary[identifier] objectForKey:@"searchPredefinedSearches"]] ;
        lua_setfield(L, -2, "searchPredefinedSearches") ;
        [skin pushNSObject:[(NSDictionary *)toolbar.itemDefDictionary[identifier] objectForKey:@"groupMembers"]] ;
        lua_setfield(L, -2, "groupMembers") ;
    }
    return 1 ;
}

/// hs.webview.toolbar:allowedItems() -> array
/// Method
/// Returns an array of all toolbar item identifiers defined for this toolbar.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table as an array of all toolbar item identifiers defined for this toolbar.  See also [hs.webview.toolbar:items](#items) and [hs.webview.toolbar:visibleItems](#visibleItems).
static int allowedToolbarItems(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[toolbar.allowedIdentifiers array]] ;
    return 1 ;
}

/// hs.webview.toolbar:items() -> array
/// Method
/// Returns an array of the toolbar item identifiers currently assigned to the toolbar.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table as an array of the currently active (assigned) toolbar item identifiers.  Toolbar items which are in the overflow menu *are* included in this array.  See also [hs.webview.toolbar:visibleItems](#visibleItems) and [hs.webview.toolbar:allowedItems](#allowedItems).
static int toolbarItems(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[toolbar.items valueForKey:@"itemIdentifier"]] ;
    return 1 ;
}

/// hs.webview.toolbar:visibleItems() -> array
/// Method
/// Returns an array of the currently visible toolbar item identifiers.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table as an array of the currently visible toolbar item identifiers.  Toolbar items which are in the overflow menu are *not* included in this array.  See also [hs.webview.toolbar:items](#items) and [hs.webview.toolbar:allowedItems](#allowedItems).
static int visibleToolbarItems(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[toolbar.visibleItems valueForKey:@"itemIdentifier"]] ;
    return 1 ;
}

/// hs.webview.toolbar:selectedItem([item]) -> toolbarObject | item
/// Method
/// Get or set the selected toolbar item
///
/// Parameters:
///  * item - an optional id for the toolbar item to show as selected, or an explicit nil if you wish for no toolbar item to be selected.
///
/// Returns:
///  * if an argument is provided, returns the toolbar object; otherwise returns the current value
///
/// Notes:
///  * Only toolbar items which were defined as `selectable` when created with [hs.webview.toolbar.new](#new) can be selected with this method.
static int selectedToolbarItem(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 2) {
        NSString *identifier = nil ;
        if (lua_type(L, 2) == LUA_TSTRING) {
            identifier = [skin toNSObjectAtIndex:2] ;
            if (!toolbar.itemDefDictionary[identifier]) {
                return luaL_error(L, "toolbar item %s does not exist", [identifier UTF8String]) ;
            }
        }

        toolbar.selectedItemIdentifier = identifier ;
        lua_pushvalue(L, 1) ;
    } else {
        [skin pushNSObject:[toolbar selectedItemIdentifier]] ;
    }
    return 1 ;
}

/// hs.webview.toolbar:selectSearchField([identifier]) -> toolbarObject | false
/// Method
/// Programmatically focus the search field for keyboard input.
///
/// Parameters:
///  * identifier - an optional string specifying the id of the specific search field to focus.  If this parameter is not provided, this method attempts to focus the first active searchfield found in the toolbar
///
/// Returns:
///  * if the searchfield can be found and is currently in the toolbar, returns the toolbarObject; otherwise returns false.
///
/// Notes:
///  * if there is current text in the searchfield, it will be selected so that any subsequent typing by the user will replace the current value in the searchfield.
static int toolbar_selectSearchField(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    NSString *targetID = (lua_gettop(L) == 2) ? [skin toNSObjectAtIndex:2] : nil ;
    NSToolbarItem *targetItem ;
    for (NSToolbarItem *item in toolbar.visibleItems) {
        if (targetID && ![targetID isEqualToString:item.itemIdentifier]) continue ;
        if ([item.view isKindOfClass:[HSToolbarSearchField class]]) {
            targetItem = item ;
            break ;
        }
    }
    if (targetItem) {
        [(HSToolbarSearchField *)targetItem.view selectText:nil] ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

/// hs.webview.toolbar:identifier() -> identifier
/// Method
/// The identifier for this toolbar.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The identifier for this toolbar.
static int toolbarIdentifier(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:toolbar.identifier] ;
    return 1 ;
}

/// hs.webview.toolbar:customizePanel() -> toolbarObject
/// Method
/// Opens the toolbar customization panel.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the toolbar object
static int customizeToolbar(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    [toolbar runCustomizationPalette:toolbar] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.webview.toolbar:isCustomizing() -> bool
/// Method
/// Indicates whether or not the customization panel is currently open for the toolbar.
///
/// Parameters:
///  * None
///
/// Returns:
///  * true or false indicating whether or not the customization panel is open for the toolbar
static int toolbarIsCustomizing(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, toolbar.customizationPaletteIsRunning) ;
    return 1 ;
}

/// hs.webview.toolbar:canCustomize([bool]) -> toolbarObject | bool
/// Method
/// Get or set whether or not the user is allowed to customize the toolbar with the Customization Panel.
///
/// Parameters:
///  * an optional boolean value indicating whether or not the user is allowed to customize the toolbar.
///
/// Returns:
///  * if an argument is provided, returns the toolbar object; otherwise returns the current value
///
/// Notes:
///  * the customization panel can be pulled up by right-clicking on the toolbar or by invoking [hs.webview.toolbar:customizePanel](#customizePanel).
static int toolbarCanCustomize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, toolbar.allowsUserCustomization) ;
    } else {
        toolbar.allowsUserCustomization = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.webview.toolbar:autosaves([bool]) -> toolbarObject | bool
/// Method
/// Get or set whether or not the toolbar autosaves changes made to the toolbar.
///
/// Parameters:
///  * an optional boolean value indicating whether or not changes made to the visible toolbar items or their order is automatically saved.
///
/// Returns:
///  * if an argument is provided, returns the toolbar object; otherwise returns the current value
///
/// Notes:
///  * If the toolbar is set to autosave, then a user-defaults entry is created in org.hammerspoon.Hammerspoon domain with the key "NSToolbar Configuration XXX" where XXX is the toolbar identifier specified when the toolbar was created.
///  * The information saved for the toolbar consists of the following:
///    * the default item identifiers that are displayed when the toolbar is first created or when the user drags the default set from the customization panel.
///    * the current display mode (icon, text, both)
///    * the current size mode (regular, small)
///    * whether or not the toolbar is currently visible
///    * the currently shown identifiers and their order
/// * Note that the labels, icons, callback functions, etc. are not saved -- these are determined at toolbar creation time, by the [hs.webview.toolbar:addItems](#addItems), or by the [hs.webview.toolbar:modifyItem](#modifyItem) method and can differ between invocations of toolbars with the same identifier and button identifiers.
static int toolbarCanAutosave(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, toolbar.autosavesConfiguration) ;
    } else {
        toolbar.autosavesConfiguration = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#ifdef _WK_DEBUG
// /// hs.webview.toolbar:infoDump() -> table
// /// Method
// /// Returns information useful for debugging
// ///
// /// Parameters:
// ///  * None
// ///
// /// Returns:
// ///  * a table containing information stored in the HSToolbar object for debugging purposes.
static int infoDump(lua_State *L) {
    LuaSkin *skin     = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TB_TAG, LS_TBREAK] ;
    HSToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    lua_newtable(L) ;
    [skin pushNSObject:[toolbar.allowedIdentifiers set]] ;    lua_setfield(L, -2, "allowedIdentifiers") ;
    [skin pushNSObject:[toolbar.defaultIdentifiers set]] ;    lua_setfield(L, -2, "defaultIdentifiers") ;
    [skin pushNSObject:[toolbar.selectableIdentifiers set]] ; lua_setfield(L, -2, "selectableIdentifiers") ;
    [skin pushNSObject:toolbar.itemDefDictionary] ;     lua_setfield(L, -2, "itemDictionary") ;
    [skin pushNSObject:toolbar.fnRefDictionary] ;       lua_setfield(L, -2, "fnRefDictionary") ;
    [skin pushNSObject:toolbar.enabledDictionary] ;     lua_setfield(L, -2, "enabledDictionary") ;
    lua_pushinteger(L, toolbar.callbackRef) ;           lua_setfield(L, -2, "callbackRef") ;
    lua_pushinteger(L, toolbar.selfRef) ;               lua_setfield(L, -2, "selfRef") ;
    [skin pushNSObject:toolbar.items] ;                 lua_setfield(L, -2, "toolbarItems") ;
    [skin pushNSObject:toolbar.delegate] ;              lua_setfield(L, -2, "delegate") ;

    NSWindow *ourWindow = toolbar.windowUsingToolbar ;
    if (ourWindow) {
        [skin pushNSObject:ourWindow withOptions:LS_NSDescribeUnknownTypes] ;
        lua_setfield(L, -2, "windowUsingToolbar") ;
        lua_pushboolean(L, [[ourWindow toolbar] isEqualTo:toolbar]) ;
        lua_setfield(L, -2, "windowUsingToolbarIsAttached") ;
    }
    return 1 ;
}
#endif

#pragma mark - Module Constants

/// hs.webview.toolbar.systemToolbarItems
/// Constant
/// An array containing string identifiers for supported system defined toolbar items.
///
/// Currently supported identifiers include:
///  * NSToolbarSpaceItem         - represents a space approximately the size of a toolbar item
///  * NSToolbarFlexibleSpaceItem - represents a space that stretches to fill available space in the toolbar
static int systemToolbarItems(lua_State *L) {
    [[LuaSkin sharedWithState:L] pushNSObject:automaticallyIncluded] ;
    return 1 ;
}

/// hs.webview.toolbar.itemPriorities
/// Constant
/// A table containing some pre-defined toolbar item priority values for use when determining item order in the toolbar.
///
/// Defined keys are:
///  * standard - the default priority for an item which does not set or change its priority
///  * low      - a low priority value
///  * high     - a high priority value
///  * user     - the priority of an item which the user has added or moved with the customization panel
static int toolbarItemPriorities(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSToolbarItemVisibilityPriorityStandard) ; lua_setfield(L, -2, "standard") ;
    lua_pushinteger(L, NSToolbarItemVisibilityPriorityLow) ;      lua_setfield(L, -2, "low") ;
    lua_pushinteger(L, NSToolbarItemVisibilityPriorityHigh) ;     lua_setfield(L, -2, "high") ;
    lua_pushinteger(L, NSToolbarItemVisibilityPriorityUser) ;     lua_setfield(L, -2, "user") ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSToolbar(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSToolbar *value = obj;
    if (value.selfRef == LUA_NOREF) {
        void** valuePtr = lua_newuserdata(L, sizeof(HSToolbar *));
        *valuePtr = (__bridge_retained void *)value;
        luaL_getmetatable(L, USERDATA_TB_TAG);
        lua_setmetatable(L, -2);
        value.selfRef = [skin luaRef:refTable] ;
        [identifiersInUse addObject:value.identifier] ;
    }

    [skin pushLuaRef:refTable ref:value.selfRef] ;
    return 1;
}

static id toHSToolbarFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSToolbar *value ;
    if (luaL_testudata(L, idx, USERDATA_TB_TAG)) {
        value = get_objectFromUserdata(__bridge HSToolbar, L, idx, USERDATA_TB_TAG) ;
        // since this function is called every time a toolbar function/method is called, we
        // can keep the window reference valid by checking here...
        [value isAttachedToWindow] ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TB_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushNSToolbarItem(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSToolbarItem *value = obj ;
    lua_newtable(L) ;
    [skin pushNSObject:value.itemIdentifier] ;     lua_setfield(L, -2, "id") ;
    [skin pushNSObject:value.label] ;              lua_setfield(L, -2, "label") ;
//     [skin pushNSObject:value.paletteLabel] ;       lua_setfield(L, -2, "paletteLabel") ;
    [skin pushNSObject:value.toolTip] ;            lua_setfield(L, -2, "tooltip") ;
    [skin pushNSObject:value.image] ;              lua_setfield(L, -2, "image") ;
    lua_pushinteger(L, value.visibilityPriority) ; lua_setfield(L, -2, "priority") ;
    lua_pushboolean(L, value.isEnabled) ;          lua_setfield(L, -2, "enable") ;
    lua_pushinteger(L, value.tag) ;                lua_setfield(L, -2, "tag") ;

    if ([obj isKindOfClass:[NSToolbarItemGroup class]]) {
        [skin pushNSObject:[obj subitems]] ; lua_setfield(L, -2, "subitems") ;
    }

//     [skin pushNSObject:value.target] ; lua_setfield(L, -2, "target") ;
//     [skin pushNSObject:NSStringFromSelector(value.action)] ; lua_setfield(L, -2, "action") ;
//     [skin pushNSObject:value.view withOptions:LS_NSDescribeUnknownTypes] ; lua_setfield(L, -2, "view") ;
//     lua_pushboolean(L, value.autovalidates) ; lua_setfield(L, -2, "autovalidates") ;

    if ([value.toolbar isKindOfClass:[HSToolbar class]]) {
        [skin pushNSObject:value.toolbar] ; lua_setfield(L, -2, "toolbar") ;

        if ([value.view isKindOfClass:[HSToolbarSearchField class]]) {
            lua_pushnumber(L, [value maxSize].width) ; lua_setfield(L, -2, "searchWidth") ;
            [skin pushNSObject:[((HSToolbarSearchField *)value.view) stringValue]] ;
            lua_setfield(L, -2, "searchText") ;
            lua_pushboolean(L, ((HSToolbarSearchField *)value.view).releaseOnCallback) ;
            lua_setfield(L, -2, "searchReleaseFocusOnCallback") ;
            lua_pushinteger(L, [[((HSToolbarSearchField *)value.view) cell] maximumRecents]) ;
            lua_setfield(L, -2, "searchHistoryLimit") ;
            [skin pushNSObject:[[((HSToolbarSearchField *)value.view) cell] recentSearches]] ;
            lua_setfield(L, -2, "searchHistory") ;
            [skin pushNSObject:[[((HSToolbarSearchField *)value.view) cell] recentsAutosaveName]] ;
            lua_setfield(L, -2, "searchHistoryAutosaveName") ;

#ifdef _WK_DEBUG
            [skin pushNSObject:NSStringFromRect(((HSToolbarSearchField *)value.view).frame)] ;
            lua_setfield(L, -2, "searchFieldFrame") ;
            [skin pushNSObject:NSStringFromSize(value.minSize)] ;
            lua_setfield(L, -2, "itemMinSize") ;
            [skin pushNSObject:NSStringFromSize(value.maxSize)] ;
            lua_setfield(L, -2, "itemMaxSize") ;
#endif
        }
    }
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSToolbar *obj = [skin luaObjectAtIndex:1 toClass:"HSToolbar"] ;
    NSString *title = obj.identifier ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TB_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TB_TAG) && luaL_testudata(L, 2, USERDATA_TB_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSToolbar *obj1 = [skin luaObjectAtIndex:1 toClass:"HSToolbar"] ;
        HSToolbar *obj2 = [skin luaObjectAtIndex:2 toClass:"HSToolbar"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

/// hs.webview.toolbar:delete() -> none
/// Method
/// Deletes the toolbar, removing it from its window if it is currently attached.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSToolbar *obj = get_objectFromUserdata(__bridge_transfer HSToolbar, L, 1, USERDATA_TB_TAG) ;
    if (obj) {
        for (NSNumber *fnRef in [obj.fnRefDictionary allValues]) [skin luaUnref:refTable ref:[fnRef intValue]] ;

        NSWindow *ourWindow = obj.windowUsingToolbar ;
        if (ourWindow && [[ourWindow toolbar] isEqualTo:obj])
            ourWindow.toolbar = nil ;

        obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef];
        obj.selfRef = [skin luaUnref:refTable ref:obj.selfRef] ;
        obj.delegate = nil ;
        // they should be properly balanced, but lets check just in case...
        NSUInteger identifierIndex = [identifiersInUse indexOfObject:obj.identifier] ;
        if (identifierIndex != NSNotFound) [identifiersInUse removeObjectAtIndex:identifierIndex] ;
        obj = nil ;
    }

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(__unused lua_State* L) {
    [identifiersInUse removeAllObjects] ;
    identifiersInUse = nil ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"_addItems",          addToolbarItems},
    {"_removeItemAtIndex", removeItemAtIndex},
    {"deleteItem",         deleteToolbarItem},
    {"delete",             userdata_gc},
    {"copyToolbar",        copyToolbar},
    {"isAttached",         isAttachedToWindow},
    {"savedSettings",      configurationDictionary},
    {"inTitleBar",         toolbar_inTitleBar},

    {"identifier",         toolbarIdentifier},
    {"setCallback",        setCallback},
    {"displayMode",        displayMode},
    {"sizeMode",           sizeMode},
    {"visible",            visible},
    {"autosaves",          toolbarCanAutosave},
    {"separator",          showsBaselineSeparator},

    {"modifyItem",         modifyToolbarItem},
    {"insertItem",         insertItemAtIndex},
    {"selectSearchField",  toolbar_selectSearchField},

    {"items",              toolbarItems},
    {"visibleItems",       visibleToolbarItems},
    {"selectedItem",       selectedToolbarItem},
    {"allowedItems",       allowedToolbarItems},
    {"itemDetails",        detailsForItemIdentifier},

    {"notifyOnChange",     notifyWhenToolbarChanges},
    {"customizePanel",     customizeToolbar},
    {"isCustomizing",      toolbarIsCustomizing},
    {"canCustomize",       toolbarCanCustomize},

#ifdef _WK_DEBUG
    {"infoDump",           infoDump},
#endif

    {"__tostring",         userdata_tostring},
    {"__eq",               userdata_eq},
    {"__gc",               userdata_gc},
    {NULL,                 NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",           newHSToolbar},
    {"attachToolbar", attachToolbar},
    {"uniqueName",    uniqueName},
    {NULL,            NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs_webview_toolbar_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TB_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    // see comment at top re @encode
    boolEncodingType = [@(YES) objCType] ;

    builtinToolbarItems = @[
                              NSToolbarSpaceItemIdentifier,
                              NSToolbarFlexibleSpaceItemIdentifier,
                              NSToolbarShowColorsItemIdentifier,       // require additional support
                              NSToolbarShowFontsItemIdentifier,        // require additional support
                              NSToolbarPrintItemIdentifier,            // require additional support
                              NSToolbarSeparatorItemIdentifier,        // deprecated
                              NSToolbarCustomizeToolbarItemIdentifier, // deprecated
                          ] ;
    automaticallyIncluded = @[
                                NSToolbarSpaceItemIdentifier,
                                NSToolbarFlexibleSpaceItemIdentifier,
                            ] ;

    keysToKeepFromDefinitionDictionary = @[ @"id", @"default", @"selectable", @"allowedAlone" ];
//     keysToKeepFromGroupDefinition      = @[ @"searchfield", @"image", @"fn" ];

    identifiersInUse = [[NSMutableArray alloc] init] ;

    systemToolbarItems(L) ;    lua_setfield(L, -2, "systemToolbarItems") ;
    toolbarItemPriorities(L) ; lua_setfield(L, -2, "itemPriorities") ;

    [skin registerPushNSHelper:pushHSToolbar         forClass:"HSToolbar"];
    [skin registerLuaObjectHelper:toHSToolbarFromLua forClass:"HSToolbar" withUserdataMapping:USERDATA_TB_TAG];
    [skin registerPushNSHelper:pushNSToolbarItem     forClass:"NSToolbarItem"];

    return 1;
}
