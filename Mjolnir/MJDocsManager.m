#import "MJDocsManager.h"
#import "MJConfigManager.h"

@implementation MJDocsManager

+ (NSURL*) docsFile {
    return [NSURL fileURLWithPath:[[MJConfigManager configPath] stringByAppendingPathComponent:@"Mjolnir.docset"]];
}

+ (NSString*) sqlFile {
    return [[[self docsFile] URLByAppendingPathComponent:@"Contents/Resources/docSet.dsidx"] path];
}

+ (void) copyDocsIfNeeded {
    if ([[NSFileManager defaultManager] fileExistsAtPath:[[MJDocsManager docsFile] path]])
        return;
    
    NSURL* docsetSourceURL = [[NSBundle mainBundle] URLForResource:@"Mjolnir" withExtension:@"docset"];
    [[NSFileManager defaultManager] copyItemAtURL:docsetSourceURL toURL:[MJDocsManager docsFile] error:NULL];
}

+ (void) installExtension:(MJExtension*)ext {
    NSString* extdir = [MJConfigManager dirForExtensionName:ext.name];
    NSString* htmlSourceDir = [extdir stringByAppendingPathComponent:@"docs.html.d"];
    NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:htmlSourceDir error:NULL];
    NSString* htmlDestDir = [[[self docsFile] URLByAppendingPathComponent:@"Contents/Resources/Documents"] path];
    
    for (NSString* file in files) {
        NSString* source = [htmlSourceDir stringByAppendingPathComponent:file];
        NSString* dest   = [htmlDestDir   stringByAppendingPathComponent:file];
        [[NSFileManager defaultManager] copyItemAtPath:source toPath:dest error:NULL];
    }
    
    NSTask* inTask = [[NSTask alloc] init];
    [inTask setLaunchPath:@"/usr/bin/sqlite3"];
    [inTask setArguments:@[[self sqlFile]]];
    [inTask setStandardInput:[NSFileHandle fileHandleForReadingAtPath:[extdir stringByAppendingPathComponent:@"docs.in.sql"]]];
    [inTask launch];
    [inTask waitUntilExit];
}

+ (void) uninstallExtension:(MJExtension*)ext {
    NSString* extdir = [MJConfigManager dirForExtensionName:ext.name];
    
    NSTask* inTask = [[NSTask alloc] init];
    [inTask setLaunchPath:@"/usr/bin/sqlite3"];
    [inTask setStandardInput:[NSFileHandle fileHandleForReadingAtPath:[extdir stringByAppendingPathComponent:@"docs.out.sql"]]];
    [inTask setArguments:@[[self sqlFile]]];
    [inTask launch];
    [inTask waitUntilExit];
    
    NSString* htmlSourceDir = [extdir stringByAppendingPathComponent:@"docs.html.d"];
    NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:htmlSourceDir error:NULL];
    NSString* htmlDestDir = [[[self docsFile] URLByAppendingPathComponent:@"Contents/Resources/Documents"] path];
    for (NSString* file in files) {
        NSString* dest = [htmlDestDir   stringByAppendingPathComponent:file];
        [[NSFileManager defaultManager] removeItemAtPath:dest error:NULL];
    }
}

@end
