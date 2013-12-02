//
//  Created by Steven Degutis
//  Copyright (c) 2013 Steven Degutis. All rights reserved.
//

#import "SDOpenAtLogin.h"

@implementation SDOpenAtLogin

+ (LSSharedFileListRef) sharedFileList {
    static LSSharedFileListRef sharedFileList;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedFileList = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    });
    return sharedFileList;
}

+ (void) setOpensAtLogin:(BOOL)opensAtLogin {
    NSURL *appURL = [[[NSBundle mainBundle] bundleURL] fileReferenceURL];
    
    if (opensAtLogin) {
        LSSharedFileListItemRef result = LSSharedFileListInsertItemURL([self sharedFileList],
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
        NSArray *sharedFileListArray = (__bridge_transfer NSArray*)LSSharedFileListCopySnapshot([self sharedFileList], &seed);
        for (id item in sharedFileListArray) {
            LSSharedFileListItemRef sharedFileItem = (__bridge LSSharedFileListItemRef)item;
            CFURLRef url = NULL;
            
            OSStatus result = LSSharedFileListItemResolve(sharedFileItem, 0, &url, NULL);
            if (result == noErr && url != nil) {
                if ([appURL isEqual: [(__bridge NSURL*)url fileReferenceURL]])
                    LSSharedFileListItemRemove([self sharedFileList], sharedFileItem);
                
                CFRelease(url);
            }
        }
    }
}

+ (BOOL) opensAtLogin {
    NSURL *appURL = [[[NSBundle mainBundle] bundleURL] fileReferenceURL];
    
    UInt32 seed;
    NSArray *sharedFileListArray = (__bridge_transfer NSArray*)LSSharedFileListCopySnapshot([self sharedFileList], &seed);
    for (id item in sharedFileListArray) {
        LSSharedFileListItemRef sharedFileItem = (__bridge LSSharedFileListItemRef)item;
        CFURLRef url = NULL;
        
        OSStatus result = LSSharedFileListItemResolve(sharedFileItem, 0, &url, NULL);
        if (result == noErr && url != NULL) {
            BOOL foundIt = [appURL isEqual: [(__bridge NSURL*)url fileReferenceURL]];
            
            CFRelease(url);
            
            if (foundIt)
                return YES;
        }
    }
    
    return NO;
}

@end
