@import Cocoa ;
@import LuaSkin ;

@interface HSjson : NSObject
-(NSString *)encode:(id)obj prettyPrint:(BOOL)prettyPrint withState:(lua_State *)L;
-(id)decode:(NSData *)json withState:(lua_State *)L;
-(BOOL)encodeToFile:(id)obj filePath:(NSString *)path replace:(BOOL)replace prettyPrint:(BOOL)prettyPrint withState:(lua_State *)L;
-(id)decodeFromFile:(NSString *)path withState:(lua_State *)L;
@end

@implementation HSjson
- (NSString *)encode:(id)obj prettyPrint:(BOOL)prettyPrint withState:(lua_State *)L {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    NSError *error;
    NSData *data;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wassign-enum"
    NSJSONWritingOptions opts = 0;
#pragma clang diagnostic pop

    if (prettyPrint) {
        opts = NSJSONWritingPrettyPrinted;
    }

    if (![NSJSONSerialization isValidJSONObject:obj]) {
        [skin logError:@"Object cannot be serialised as JSON"];
        return nil;
    }

    data = [NSJSONSerialization dataWithJSONObject:obj
                                           options:opts
                                             error:&error];

    if (error) {
        [skin logError:[NSString stringWithFormat:@"Unable to serialise JSON: %@", error.localizedDescription]];
        return nil;
    }

    return [[NSString alloc] initWithData:data
                                 encoding:NSUTF8StringEncoding];
}

- (id)decode:(NSData *)data withState:(lua_State *)L {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    NSError *error;

    if (!data) {
        [skin logError:@"Unable to convert JSON to NSData object"];
        return nil;
    }

    id obj = [NSJSONSerialization JSONObjectWithData:data
                                             options:NSJSONReadingFragmentsAllowed
                                               error:&error];

    if (error) {
        [skin logError:[NSString stringWithFormat:@"Error deserialising JSON: %@", error.localizedDescription]];
        return nil;
    }

    return obj;
}

- (BOOL)encodeToFile:(id)obj
            filePath:(NSString *)path
             replace:(BOOL)replace
         prettyPrint:(BOOL)prettyPrint
           withState:(lua_State *)L {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    NSError *error;
    NSString *json = [self encode:obj prettyPrint:prettyPrint withState:L];

    if (!json) {
        [skin logError:@"Failed to write object to JSON file"];
        return NO;
    }

    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        [skin logError:@"Unable to convert JSON to NSData object"];
        return NO;
    }

    // Note to future optimisers: We can't use NSString's file writing method
    //  because it unconditionally overwrites files.
    BOOL writeStatus = [data writeToFile:path
                                 options:(replace ? NSDataWritingAtomic : NSDataWritingWithoutOverwriting)
                                   error:&error];

    if (!writeStatus) {
        [skin logError:[NSString stringWithFormat:@"Error writing JSON to file: %@", error.localizedDescription]];
        return NO;
    }

    return YES;
}

- (id)decodeFromFile:(NSString *)path withState:(lua_State *)L {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    NSError *error = nil;
    NSData *json = [NSData dataWithContentsOfFile:path options:0 error:&error];

    if (error) {
        [skin logError:[NSString stringWithFormat:@"Error reading JSON from file: %@", error.localizedDescription]];
        return nil;
    }

    return [self decode:json withState:L];
}
@end

/// hs.json.encode(val[, prettyprint]) -> string
/// Function
/// Encodes a table as JSON
///
/// Parameters:
///  * val - A table containing data to be encoded as JSON
///  * prettyprint - An optional boolean, true to format the JSON for human readability, false to format the JSON for size efficiency. Defaults to false
///
/// Returns:
///  * A string containing a JSON representation of the supplied table
///
/// Notes:
///  * This is useful for storing some of the more complex lua table structures as a persistent setting (see `hs.settings`)
static int json_encode(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TTABLE, LS_TBOOLEAN|LS_TOPTIONAL, LS_TBREAK];

    HSjson *jsonManager = [[HSjson alloc] init];

    id table = [skin toNSObjectAtIndex:1];
    BOOL prettyPrint = lua_toboolean(L, 2);

    NSString *json = [jsonManager encode:table prettyPrint:prettyPrint withState:L];
    [skin pushNSObject:json];
    return 1;
}

/// hs.json.decode(jsonString) -> table
/// Function
/// Decodes JSON into a table
///
/// Parameters:
///  * jsonString - A string containing some JSON data
///
/// Returns:
///  * A table representing the supplied JSON data
///
/// Notes:
///  * This is useful for retrieving some of the more complex lua table structures as a persistent setting (see `hs.settings`)
static int json_decode(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];

    HSjson *jsonManager = [[HSjson alloc] init];

    NSData* data = [skin toNSObjectAtIndex:1 withOptions:LS_NSLuaStringAsDataOnly];

    id table = [jsonManager decode:data withState:L];
    [skin pushNSObject:table];
    return 1;
}

/// hs.json.write(data, path, [prettyprint], [replace]) -> boolean
/// Function
/// Encodes a table as JSON to a file
///
/// Parameters:
///  * data - A table containing data to be encoded as JSON
///  * path - The path and filename of the JSON file to write to
///  * prettyprint - An optional boolean, `true` to format the JSON for human readability, `false` to format the JSON for size efficiency. Defaults to `false`
///  * replace - An optional boolean, `true` to replace an existing file at the same path if one exists. Defaults to `false`
///
/// Returns:
///  * `true` if successful otherwise `false` if an error has occurred
static int json_write(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TTABLE, LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];

    HSjson *jsonManager = [[HSjson alloc] init];

    id table = [skin toNSObjectAtIndex:1];
    NSString *filePath = [[skin toNSObjectAtIndex:2] stringByExpandingTildeInPath];
    BOOL prettyPrint = lua_toboolean(L, 3);
    BOOL replace = lua_toboolean(L, 4);

    BOOL result = [jsonManager encodeToFile:table
                                   filePath:filePath
                                    replace:replace
                                prettyPrint:prettyPrint
                                  withState:L];

    lua_pushboolean(L, result);
    return 1;
}

/// hs.json.read(path) -> table | nil
/// Function
/// Decodes JSON file into a table.
///
/// Parameters:
///  * path - The path and filename of the JSON file to read.
///
/// Returns:
///  * A table representing the supplied JSON data, or `nil` if an error occurs.
static int json_read(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];

    HSjson *jsonManager = [[HSjson alloc] init];

    NSString *filePath = [[skin toNSObjectAtIndex:1] stringByExpandingTildeInPath];

    id table = [jsonManager decodeFromFile:filePath withState:L];
    [skin pushNSObject:table];
    return 1;
}

// Functions for returned object when module loads
static const luaL_Reg jsonLib[] = {
    {"encode",  json_encode},
    {"decode",  json_decode},
    {"read",    json_read},
    {"write",   json_write},
    {NULL,      NULL}
};

int luaopen_hs_libjson(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibrary:"hs.json" functions:jsonLib metaFunctions:nil];

    return 1;
}
