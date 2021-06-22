@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs.doc" ; // we're using it as a module tag for console messages

static LSRefTable refTable = LUA_NOREF;
static int refTriggerFn = LUA_NOREF ;

static NSMutableDictionary *registeredFiles ;
static NSMutableDictionary *documentationTree ;

#pragma mark - Support Functions and Classes

NSInteger docSortFunction(NSString *a, NSString *b, __unused void *context) {
    NSError *error = nil ;
    NSRegularExpression *parser = [NSRegularExpression regularExpressionWithPattern:@"^_\\d([\\d_])*"
                                                                            options:NSRegularExpressionUseUnicodeWordBoundaries
                                                                              error:&error] ;
    if (!error) {
        NSTextCheckingResult *aMatch = [parser firstMatchInString:a options:0 range:NSMakeRange(0, a.length)] ;
        NSTextCheckingResult *bMatch = [parser firstMatchInString:b options:0 range:NSMakeRange(0, b.length)] ;
        if (aMatch.range.length != 0 && bMatch.range.length != 0) {
            NSString *aTag = [a substringWithRange:aMatch.range] ;
            NSString *bTag = [b substringWithRange:bMatch.range] ;
            parser = [NSRegularExpression regularExpressionWithPattern:@"\\d+"
                                                               options:NSRegularExpressionUseUnicodeWordBoundaries
                                                                 error:&error] ;
            if (!error) {
                NSArray *aNumericParts = [parser matchesInString:aTag options:0 range:NSMakeRange(0, aTag.length)] ;
                NSArray *bNumericParts = [parser matchesInString:bTag options:0 range:NSMakeRange(0, bTag.length)] ;

                NSUInteger minCount = (aNumericParts.count < bNumericParts.count) ? aNumericParts.count : bNumericParts.count ;
                NSNumberFormatter *f = [[NSNumberFormatter alloc] init] ;
                f.numberStyle = NSNumberFormatterNoStyle ;
                for (NSUInteger i = 0 ; i < minCount ; i++) {
                    NSTextCheckingResult *aPartMatch = aNumericParts[i] ;
                    NSTextCheckingResult *bPartMatch = bNumericParts[i] ;
                    NSNumber *aNumber = [f numberFromString:[a substringWithRange:aPartMatch.range]] ;
                    NSNumber *bNumber = [f numberFromString:[b substringWithRange:bPartMatch.range]] ;
                    NSComparisonResult test = [aNumber compare:bNumber] ;
                    if (test != NSOrderedSame) return test ;
                }
                return (aNumericParts.count < bNumericParts.count) ? NSOrderedAscending
                                                                   : ((aNumericParts.count > bNumericParts.count) ? NSOrderedDescending : NSOrderedSame) ;
            } else {
                [LuaSkin logError:[NSString stringWithFormat:@"%s.docSortFunction - error initializing 2nd regex: %@", USERDATA_TAG, error.localizedDescription]] ;
            }
        }
    } else {
        [LuaSkin logError:[NSString stringWithFormat:@"%s.docSortFunction - error initializing regex: %@", USERDATA_TAG, error.localizedDescription]] ;
    }
    return [a caseInsensitiveCompare:b] ;
}

static BOOL processRegisteredFile(lua_State *L, NSString *path) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    NSError *error = nil ;
    NSData *rawFile = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:&error] ;
    if (!rawFile || error) {
        [skin logError:[NSString stringWithFormat:@"%s.processRegisteredFile - unable to open '%@' (%@)", USERDATA_TAG, path, error.localizedDescription]] ;
        return NO ;
    }

    id obj = [NSJSONSerialization JSONObjectWithData:rawFile options:NSJSONReadingAllowFragments error:&error] ;
    if (error) {
        [skin logError:[NSString stringWithFormat:@"%s.processRegisteredFile - error parsing JSON for %@: %@", USERDATA_TAG, path, error.localizedDescription]] ;
        return NO ;
    } else if (!obj) {
        [skin logError:[NSString stringWithFormat:@"%s.processRegisteredFile - error parsing JSON for %@: input resolved to nil", USERDATA_TAG, path]] ;
        return NO ;
    }

    registeredFiles[path][@"json"]  = obj ;

    BOOL isSpoon = [(NSNumber *)registeredFiles[path][@"spoon"] boolValue] ;
    NSMutableDictionary *root = isSpoon ? documentationTree[@"spoon"] : documentationTree ;

    if (![(NSObject *)obj isKindOfClass:[NSArray class]]) {
        [skin logError:[NSString stringWithFormat:@"%s.processRegisteredFile - malformed documentation file %@: proper format requires an array of entries", USERDATA_TAG, path]] ;
        return NO ;
    }

    NSRegularExpression *parser = [NSRegularExpression
                                      regularExpressionWithPattern:@"[\\w_]+"
                                                           options:NSRegularExpressionUseUnicodeWordBoundaries
                                                             error:&error
                                  ] ;
    if (!error) {
        [(NSArray *)obj enumerateObjectsUsingBlock:^(NSDictionary *entry, NSUInteger idx, __unused BOOL *stop) {
            __block NSMutableDictionary *pos = root ;

            if (![entry isKindOfClass:[NSDictionary class]] || !entry[@"name"]) {
                [skin logError:[NSString stringWithFormat:@"%s.processRegisteredFile - malformed entry in %@ -- expected module dictionary with 'name' key at index %lu in %@; skipping", USERDATA_TAG, path, idx + 1, path]] ;
            } else {
                NSString *entryName = entry[@"name"] ;
                [parser enumerateMatchesInString:entryName
                                         options:0
                                           range:NSMakeRange(0, entryName.length)
                                      usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags __unused flags, __unused BOOL *stop2) {
                    NSString *part = [entryName substringWithRange:match.range] ;
                    if (!pos[part]) pos[part] = [@{ @"__type__" : @"placeholder" } mutableCopy] ;
                    pos = pos[part] ;
                }] ;

                if (pos[@"__json__"]) {
                    // FIXME: Duplicate Handling
                    //    In theory additions or changes to the module could be defined elsewhere. Bad style, so log anyways, and we'll
                    //    decide how to officially handle it if it becomes normal as opposed to an "in-development" shortcut. For now,
                    //    assume since coredocs are loaded first, that this is an in-progress update that should overwrite the original.
                    [skin logInfo:[NSString stringWithFormat:@"%s.processRegisteredFile - duplicate module entry in %@ for %@ (%@)", USERDATA_TAG, path, entryName, entry[@"desc"]]] ;
                }
                pos[@"__json__"] = entry ;
                pos[@"__type__"] = @"module" ; // this is more than a placeholder now

                if (entry[@"items"]) {
                    NSArray *itemsAttached = entry[@"items"] ;
                    if ([itemsAttached isKindOfClass:[NSArray class]]) {
                        [(NSArray *)entry[@"items"] enumerateObjectsUsingBlock:^(NSDictionary *itemEntry, NSUInteger idx2, __unused BOOL *stop2) {

                        if (![itemEntry isKindOfClass:[NSDictionary class]] || !itemEntry[@"name"]) {
                            [skin logInfo:[NSString stringWithFormat:@"%s.processRegisteredFile - malformed entry in %@ -- expected item dictionary with 'name' key for %@ at index %lu; skipping", USERDATA_TAG, path, entryName, idx2 + 1]] ;
                        } else {
                            NSString *itemName = itemEntry[@"name"] ;
                            NSTextCheckingResult *match = [parser firstMatchInString:itemName options:0 range:NSMakeRange(0, itemName.length)] ;
                            if (match.range.location != NSNotFound) {
                                NSString *part = [itemName substringWithRange:match.range] ;
                                if (pos[part]) {
                                    // FIXME: Duplicate Handling
                                    //     See above for current behavior and reasoning
                                    [skin logInfo:[NSString stringWithFormat:@"%s.processRegisteredFile - duplicate item in %@: %@ (%@) for %@", USERDATA_TAG, path, itemName, entry[@"def"], entryName]] ;
                                }
                                NSMutableDictionary *itemDict = [@{ @"__type__" : @"entry" } mutableCopy] ;
                                itemDict[@"__json__"] = itemEntry ;
                                pos[part] = itemDict ;
                            } else {
                                [skin logInfo:[NSString stringWithFormat:@"%s.processRegisteredFile - malformed entry in %@ -- item name (%@) invalid for %@ at index %lu; skipping", USERDATA_TAG, path, itemName, entryName, idx2 + 1]] ;
                            }
                        }
                    }] ;
                    } else {
                        [skin logInfo:[NSString stringWithFormat:@"%s.processRegisteredFile - malformed entry in %@ -- expected array or nil in 'items' key for %@ at index %lu; skipping", USERDATA_TAG, path, entryName, idx + 1]] ;
                    }
                } // no items at all is ok, we only log when items isn't an array
            }
        }] ;

        // make sure watchers knows that something has changed
        [skin pushLuaRef:refTable ref:refTriggerFn] ;
        lua_call(L, 0, 0) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"%s.processRegisteredFile - error initializing regex: %@", USERDATA_TAG, error.localizedDescription]] ;
    }

    return YES ;
}

static void findUnloadedDocumentationFiles(lua_State *L) {
    NSArray *paths = [registeredFiles allKeys] ;
    [paths enumerateObjectsUsingBlock:^(NSString *path, __unused NSUInteger idx, __unused BOOL *stop) {
        NSMutableDictionary *entry = registeredFiles[path] ;
        if (!entry[@"json"]) processRegisteredFile(L, path) ;
    }] ;
}

NSMutableDictionary *getPosInTreeFor(NSString *target) {
    __block NSMutableDictionary *pos ;

    NSError *error = nil ;
    NSRegularExpression *parser = [NSRegularExpression regularExpressionWithPattern:@"[^.]+"
                                                                            options:NSRegularExpressionUseUnicodeWordBoundaries
                                                                              error:&error] ;
    if (!error) {
        pos = documentationTree ;
        [parser enumerateMatchesInString:target
                                 options:0
                                   range:NSMakeRange(0, target.length)
                              usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags __unused flags, BOOL *stop) {
            NSString *part = [target substringWithRange:match.range] ;
            if (pos[part]) {
                pos = pos[part] ;
            } else {
                pos = nil ;
                *stop = YES ;
            }
        }] ;
    } else {
        [LuaSkin logError:[NSString stringWithFormat:@"%s.getPosInTreeFor - error initializing regex: %@", USERDATA_TAG, error.localizedDescription]] ;
    }

    return pos ;
}

#pragma mark - Module Functions

// documented in init.lua
static int doc_help(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *identifier = @"" ;
    if (lua_gettop(L) == 1 && lua_type(L, 1) == LUA_TSTRING) identifier = [skin toNSObjectAtIndex:1] ;

    findUnloadedDocumentationFiles(L) ;

    NSMutableString *result = [[NSMutableString alloc] init] ;

    NSMutableDictionary *pos = getPosInTreeFor(identifier) ;

    if (pos) {
        result = [[NSMutableString alloc] init] ;

        if ([(NSString *)pos[@"__type__"] isEqualToString:@"root"]) {
            [result appendString:@"[modules]\n"] ;
            NSMutableArray *children = [[(NSDictionary *)pos allKeys] mutableCopy] ;
            [children sortUsingSelector:@selector(caseInsensitiveCompare:)] ;
            for (NSString *entry in children) {
                if (!([entry hasPrefix:@"__"] && [entry hasSuffix:@"__"])) {
                    [result appendFormat:@"%@\n", entry] ;
                }
            }
        } else if ([(NSString *)pos[@"__type__"] isEqualToString:@"spoons"]) {
            [result appendString:@"[spoons]\n"] ;
            NSMutableArray *children = [[(NSDictionary *)pos allKeys] mutableCopy] ;
            [children sortUsingSelector:@selector(caseInsensitiveCompare:)] ;
            for (NSString *entry in children) {
                if (!([entry hasPrefix:@"__"] && [entry hasSuffix:@"__"])) {
                    [result appendFormat:@"%@\n", entry] ;
                }
            }
        } else if (pos[@"__json__"] && !pos[@"__json__"][@"items"]) {
            [result appendFormat:@"%@: %@\n\n%@\n",
                pos[@"__json__"][@"type"],
                (pos[@"__json__"][@"signature"] ? pos[@"__json__"][@"signature"] : pos[@"__json__"][@"def"]),
                pos[@"__json__"][@"doc"]
            ] ;
        } else {
            if (pos[@"__json__"]) {
                [result appendFormat:@"%@", pos[@"__json__"][@"doc"]] ;
            } else {
                [result appendString:@"** DOCUMENTATION MISSING **"] ;
            }
            NSMutableString *submodules = [[NSMutableString alloc] init] ;
            NSMutableString *items      = [[NSMutableString alloc] init] ;
            NSMutableArray *children = [[(NSDictionary *)pos allKeys] mutableCopy] ;
            [children sortUsingFunction:docSortFunction context:NULL] ;
            [children enumerateObjectsUsingBlock:^(NSString *entry, __unused NSUInteger idx, __unused BOOL *stop) {
                if (!([entry hasPrefix:@"__"] && [entry hasSuffix:@"__"])) {
                    if (!pos[entry][@"__json__"] || !pos[entry][@"__json__"][@"type"] || [(NSString *)pos[entry][@"__json__"][@"type"] isEqualToString:@"Module"]) {
                        [submodules appendFormat:@"%@\n", entry] ;
                    } else {
                        NSString *itemSignature = pos[entry][@"__json__"][@"signature"] ? pos[entry][@"__json__"][@"signature"] : pos[entry][@"__json__"][@"def"] ;
                        [items appendFormat:@"%@\n", itemSignature] ;
                    }
                }
            }] ;
            [result appendFormat:@"\n\n[submodules]\n%@\n[items]\n%@\n", submodules, items] ;
        }
    }

    [skin pushNSObject:result] ;
    return 1 ;
}

/// hs.doc.registerJSONFile(jsonfile, [isSpoon]) -> status[, message]
/// Function
/// Register a JSON file for inclusion when Hammerspoon generates internal documentation.
///
/// Parameters:
///  * jsonfile - A string containing the location of a JSON file
///  * isSpoon  - an optional boolean, default false, specifying that the documentation should be added to the `spoons` sub heading in the documentation hierarchy.
///
/// Returns:
///  * status - Boolean flag indicating if the file was registered or not.  If the file was not registered, then a message indicating the error is also returned.
///
/// Notes:
///  * this function just registers the documentation file; it won't actually be loaded and parsed until [hs.doc.help](#help) is invoked.
static int doc_registerJSONFile(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *path   = [skin toNSObjectAtIndex:1] ;
    BOOL     isSpoon = (lua_gettop(L) > 1) ? lua_toboolean(L, 2) : NO ;

    // some tricks used to figure out if the docs.json file exists duplicate final "/" before "docs.json"
    // so rather then track them all down, just adjust it here; otherwise we have two "different" paths
    // containing the same data and get a lot of duplicate entry warnings
    path = [[path stringByStandardizingPath] stringByResolvingSymlinksInPath] ;

    if (registeredFiles[path]) {
        lua_pushboolean(L, NO) ;
        [skin pushNSObject:[NSString stringWithFormat:@"File '%@' already registered", path]] ;
        return 2 ;
    }

    registeredFiles[path] = [[NSMutableDictionary alloc] init] ;
    registeredFiles[path][@"spoon"] = @(isSpoon) ;

    // changecount function will be triggered when json bult in findUnloadedDocumentationFiles for new path

    lua_pushboolean(L, YES) ;
    return 1 ;
}

/// hs.doc.unregisterJSONFile(jsonfile) -> status[, message]
/// Function
/// Remove a JSON file from the list of registered files.
///
/// Parameters:
///  * jsonfile - A string containing the location of a JSON file
///
/// Returns:
///  * status - Boolean flag indicating if the file was unregistered or not.  If the file was not unregistered, then a message indicating the error is also returned.
///
/// Notes:
///  * This function requires the rebuilding of the entire documentation tree for all remaining registered files, so the next time help is queried with [hs.doc.help](#help), there may be a slight one-time delay.
static int doc_unregisterJSONFile(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *path   = [skin toNSObjectAtIndex:1] ;

    if (!registeredFiles[path]) {
        lua_pushboolean(L, NO) ;
        [skin pushNSObject:[NSString stringWithFormat:@"File '%@' was not registered", path]] ;
        return 2 ;
    }

    registeredFiles[path] = nil ;
    [documentationTree removeAllObjects] ;
    documentationTree         = [@{
        @"__type__" : @"root",
        @"spoon"    : [@{ @"__type__" : @"spoons" } mutableCopy],
    } mutableCopy] ;

    NSArray *paths = [registeredFiles allKeys] ;
    [paths enumerateObjectsUsingBlock:^(NSString *path2, __unused NSUInteger idx, __unused BOOL *stop) {
        NSMutableDictionary *entry = registeredFiles[path2] ;
        if (entry[@"json"]) entry[@"json"] = nil ;
    }] ;

    // changecount function will be triggered when json rebuilt in findUnloadedDocumentationFiles for remaining paths

    lua_pushboolean(L, YES) ;
    return 1 ;
}

// documented in init.lua
static int doc_registeredFiles(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    NSMutableArray *sortedPaths = [[registeredFiles allKeys] mutableCopy] ;
    [sortedPaths sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)] ;
    [skin pushNSObject:sortedPaths] ;
    return 1 ;
}

// // Wasn't actually used by anything outside of this module, and now it's not necessary at all,
// // but if we find out somone misses it, we can easily re-add it by uncommenting this and
// /// the entry in moduleLib below
// //
// /// hs.doc.validateJSONFile(jsonfile) -> status, message|table
// /// Function
// /// Validate a JSON file potential inclusion in the Hammerspoon internal documentation.
// ///
// /// Parameters:
// ///  * jsonfile - A string containing the location of a JSON file
// ///
// /// Returns:
// ///  * status - Boolean flag indicating if the file was validated or not.
// ///  * message|table - If the file did not contain valid JSON data, then a message indicating the error is returned; otherwise the parsed JSON data is returned as a table.
// static int doc_validateJSONFile(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
//     NSString *path   = [skin toNSObjectAtIndex:1] ;
//
//     NSError *error ;
//     NSData *rawFile = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:&error] ;
//     if (!rawFile || error) {
//         lua_pushboolean(L, NO) ;
//         [skin pushNSObject:[NSString stringWithFormat:@"Unable to open '%@' (%@)", path, error.localizedDescription]] ;
//         return 2 ;
//     }
//
//     id obj = [NSJSONSerialization JSONObjectWithData:fileData options:NSJSONReadingAllowFragments error:&error] ;
//     if (error) {
//         lua_pushboolean(L, NO) ;
//         [skin pushNSObject:error.localizedDescription] ;
//     } else if (obj) {
//         lua_pushboolean(L, YES) ;
//         [skin pushNSObject:obj] ;
//     } else {
//         lua_pushboolean(L, NO) ;
//         [skin pushNSObject:@"json input returned nil"] ;
//     }
//     return 2 ;
// }

#pragma mark - Internal Use Functions

// returns list of children in documentTree for __index and __pairs of helper table for `help`
static int internal_arrayOfChildren(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *identifier = @"" ;
    if (lua_gettop(L) == 1 && lua_type(L, 1) == LUA_TSTRING) identifier = [skin toNSObjectAtIndex:1] ;

    lua_newtable(L) ;

    NSMutableDictionary *pos = getPosInTreeFor(identifier) ;

    if (pos) {
        for (NSString *entry in [(NSDictionary *)pos allKeys]) {
            if (!([entry hasPrefix:@"__"] && [entry hasSuffix:@"__"])) {
                [skin pushNSObject:entry] ;
                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
        }
    }
    return 1 ;
}

// used by doc_help and when json being rebuilt for hsdocs
static int internal_loadRegisteredFiles(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    findUnloadedDocumentationFiles(L) ;
    return 0 ;
}

// used to register lua function to trigger `hs.watchable` change counter so hsdocs knows when doc files have been updated
static int internal_registerTriggerFunction(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TFUNCTION, LS_TBREAK] ;

    if (refTriggerFn != LUA_NOREF && refTriggerFn != LUA_REFNIL) {
        refTriggerFn = [skin luaUnref:refTable ref:refTriggerFn] ;
    }
    lua_pushvalue(L, 1) ;
    refTriggerFn = [skin luaRef:refTable] ;
    return 0 ;
}

#pragma mark - objectWrapper Constructors

// returns objectWrapper for registeredFiles
static int internal_registeredFiles(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:registeredFiles withOptions:LS_WithObjectWrapper | LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

// returns objectWrapper for documentationTree
static int internal_documentationTree(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:documentationTree withOptions:LS_WithObjectWrapper | LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int meta_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTriggerFn = [skin luaUnref:refTable ref:refTriggerFn] ;

    // probably overkill, but lets just be official about it
    [registeredFiles removeAllObjects] ;
    registeredFiles = nil ;
    [documentationTree removeAllObjects] ;
    documentationTree = nil ;
    return 0 ;
}

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"help",               doc_help},
    {"registerJSONFile",   doc_registerJSONFile},
    {"registeredFiles",    doc_registeredFiles},
    {"unregisterJSONFile", doc_unregisterJSONFile},
//     {"validateJSONFile",   doc_validateJSONFile},

    {NULL, NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"_children",                internal_arrayOfChildren},
    {"_loadRegisteredFiles",     internal_loadRegisteredFiles},
    {"_registerTriggerFunction", internal_registerTriggerFunction},

    {"_registeredFilesObject",   internal_registeredFiles},
    {"_documentationTreeObject", internal_documentationTree},

    {"__gc",                     meta_gc},

    {NULL,   NULL}
};

int luaopen_hs_doc_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibrary:USERDATA_TAG functions:moduleLib metaFunctions:module_metaLib] ;

    registeredFiles = [[NSMutableDictionary alloc] init] ;
    // if you change this, also change it in doc_unregisterJSONFile
    documentationTree         = [@{
        @"__type__" : @"root",
        @"spoon"    : [@{ @"__type__" : @"spoons" } mutableCopy],
    } mutableCopy] ;


    return 1;
}
