#import "PKDocsManager.h"

@implementation PKDocsManager

+ (PKDocsManager*) sharedManager {
    static PKDocsManager* sharedManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[PKDocsManager alloc] init];
    });
    return sharedManager;
}

+ (NSURL*) userLocation {
    return [NSURL fileURLWithPath:[@"~/.penknife/Penknife.docset" stringByStandardizingPath]];
}

+ (void) copyDocsIfNeeded {
    if ([[NSFileManager defaultManager] fileExistsAtPath:[[PKDocsManager userLocation] path]])
        return;
    
    NSURL* docsetSourceURL = [[NSBundle mainBundle] URLForResource:@"Penknife" withExtension:@"docset"];
    [[NSFileManager defaultManager] copyItemAtURL:docsetSourceURL toURL:[PKDocsManager userLocation] error:NULL];
}

@end
