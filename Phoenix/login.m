#import "lua/lauxlib.h"

static LSSharedFileListRef shared_file_list() {
    static LSSharedFileListRef sharedFileList;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedFileList = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    });
    return sharedFileList;
}

int open_at_login_get(lua_State* L) {
    NSURL *appURL = [[[NSBundle mainBundle] bundleURL] fileReferenceURL];
    
    UInt32 seed;
    NSArray *sharedFileListArray = (__bridge_transfer NSArray*)LSSharedFileListCopySnapshot(shared_file_list(), &seed);
    for (id item in sharedFileListArray) {
        LSSharedFileListItemRef sharedFileItem = (__bridge LSSharedFileListItemRef)item;
        CFURLRef url = NULL;
        
        OSStatus result = LSSharedFileListItemResolve(sharedFileItem, 0, &url, NULL);
        if (result == noErr && url != NULL) {
            BOOL foundIt = [appURL isEqual: [(__bridge NSURL*)url fileReferenceURL]];
            
            CFRelease(url);
            
            if (foundIt) {
                lua_pushboolean(L, YES);
                return 1;
            }
        }
    }
    
    lua_pushboolean(L, NO);
    return 1;
}

int open_at_login_set(lua_State* L) {
    BOOL opensAtLogin = lua_tonumber(L, 1);
    
    NSURL *appURL = [[[NSBundle mainBundle] bundleURL] fileReferenceURL];
    
    if (opensAtLogin) {
        LSSharedFileListItemRef result = LSSharedFileListInsertItemURL(shared_file_list(),
                                                                       kLSSharedFileListItemLast,
                                                                       NULL,
                                                                       NULL,
                                                                       (__bridge CFURLRef)appURL,
                                                                       NULL,
                                                                       NULL);
        CFRelease(result);
    }
    else {
        UInt32 seed;
        NSArray *sharedFileListArray = (__bridge_transfer NSArray*)LSSharedFileListCopySnapshot(shared_file_list(), &seed);
        for (id item in sharedFileListArray) {
            LSSharedFileListItemRef sharedFileItem = (__bridge LSSharedFileListItemRef)item;
            CFURLRef url = NULL;
            
            OSStatus result = LSSharedFileListItemResolve(sharedFileItem, 0, &url, NULL);
            if (result == noErr && url != nil) {
                if ([appURL isEqual: [(__bridge NSURL*)url fileReferenceURL]])
                    LSSharedFileListItemRemove(shared_file_list(), sharedFileItem);
                
                CFRelease(url);
            }
        }
    }
    return 0;
}
