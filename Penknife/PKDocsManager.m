#import "PKDocsManager.h"

@implementation PKDocsManager

+ (NSURL*) docsFile {
    return [NSURL fileURLWithPath:[@"~/.penknife/Penknife.docset" stringByStandardizingPath]];
}

+ (void) copyDocsIfNeeded {
    if ([[NSFileManager defaultManager] fileExistsAtPath:[[PKDocsManager docsFile] path]])
        return;
    
    NSURL* docsetSourceURL = [[NSBundle mainBundle] URLForResource:@"Penknife" withExtension:@"docset"];
    [[NSFileManager defaultManager] copyItemAtURL:docsetSourceURL toURL:[PKDocsManager docsFile] error:NULL];
}

+ (void) installExtension:(PKExtension*)ext {
    
}

+ (void) uninstallExtension:(PKExtension*)ext {
    
}

@end
