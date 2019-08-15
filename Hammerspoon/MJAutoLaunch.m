#import "MJAutoLaunch.h"

static LSSharedFileListRef shared_file_list() {
    static LSSharedFileListRef list;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        list = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
#pragma clang diagnostic pop
    });
    return list;
}

BOOL MJAutoLaunchGet(void) {
    NSURL *appURL = [[[NSBundle mainBundle] bundleURL] fileReferenceURL];
    
    UInt32 seed;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSArray *sharedFileListArray = (__bridge_transfer NSArray*)LSSharedFileListCopySnapshot(shared_file_list(), &seed);
#pragma clang diagnostic pop
    for (id item in sharedFileListArray) {
        LSSharedFileListItemRef sharedFileItem = (__bridge LSSharedFileListItemRef)item;
        CFURLRef url = NULL;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        OSStatus result = LSSharedFileListItemResolve(sharedFileItem, 0, &url, NULL);
#pragma clang diagnostic pop
        if (result == noErr && url != NULL) {
            BOOL foundIt = [appURL isEqual: [(__bridge NSURL*)url fileReferenceURL]];
            
            CFRelease(url);
            
            if (foundIt) {
                return YES;
            }
        }
    }
    
    return NO;
}

void MJAutoLaunchSet(BOOL opensAtLogin) {
    NSURL *appURL = [[[NSBundle mainBundle] bundleURL] fileReferenceURL];

    if (!appURL) {
        NSLog(@"ERROR: Unable to get mainBundle URL");
        return;
    }
    
    if (opensAtLogin) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        LSSharedFileListItemRef result = LSSharedFileListInsertItemURL(shared_file_list(),
                                                                       kLSSharedFileListItemLast,
                                                                       NULL,
                                                                       NULL,
                                                                       (__bridge CFURLRef)appURL,
                                                                       NULL,
                                                                       NULL);
#pragma clang diagnostic pop
        if (result) CFRelease(result);
    }
    else {
        UInt32 seed;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSArray *sharedFileListArray = (__bridge_transfer NSArray*)LSSharedFileListCopySnapshot(shared_file_list(), &seed);
#pragma clang diagnostic pop
        for (id item in sharedFileListArray) {
            LSSharedFileListItemRef sharedFileItem = (__bridge LSSharedFileListItemRef)item;
            CFURLRef url = NULL;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            OSStatus result = LSSharedFileListItemResolve(sharedFileItem, 0, &url, NULL);
#pragma clang diagnostic pop
            if (result == noErr && url != nil) {
                if ([appURL isEqual: [(__bridge NSURL*)url fileReferenceURL]])
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    LSSharedFileListItemRemove(shared_file_list(), sharedFileItem);
#pragma clang diagnostic pop
                
                CFRelease(url);
            }
        }
    }
}
