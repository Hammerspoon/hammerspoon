#import "MJDocsManager.h"
#import "MJConfigManager.h"
#import "MJFileUtils.h"

@implementation MJDocsManager

+ (NSURL*) docsFile {
    return [NSURL fileURLWithPath:[[MJConfigManager configPath] stringByAppendingPathComponent:@"Mjolnir.docset"]];
}

+ (NSString*) masterSqlFile {
    return [[[self docsFile] URLByAppendingPathComponent:@"Contents/Resources/docSet.dsidx"] path];
}

+ (void) copyDocsIfNeeded {
    if ([[NSFileManager defaultManager] fileExistsAtPath:[[MJDocsManager docsFile] path]])
        return;
    
    NSURL* docsetSourceURL = [[NSBundle mainBundle] URLForResource:@"Mjolnir" withExtension:@"docset"];
    [[NSFileManager defaultManager] copyItemAtURL:docsetSourceURL toURL:[MJDocsManager docsFile] error:NULL];
}

+ (NSString*) sharedHtmlDocsDir {
    return [[[self docsFile] URLByAppendingPathComponent:@"Contents/Resources/Documents"] path];
}

+ (NSString*) htmlDocsDirInExtensionDirectory:(NSString*)extdir {
    return [extdir stringByAppendingPathComponent:@"docs.html.d"];
}

+ (BOOL) runSqlFile:(NSString*)sqlfile inDir:(NSString*)extdir error:(NSError* __autoreleasing*)error {
    NSData* masterSqlFileData = [NSData dataWithContentsOfFile:[self masterSqlFile] options:0 error:error];
    NSString* masterSqlFile = [self masterSqlFile];
    
    NSString* masterSqlFileCopy = MJWriteToTempFile(masterSqlFileData, @"master.", @".sql", error);
    
    NSTask* inTask = [[NSTask alloc] init];
    [inTask setLaunchPath:@"/usr/bin/sqlite3"];
    [inTask setStandardInput:[NSFileHandle fileHandleForReadingAtPath:[extdir stringByAppendingPathComponent:sqlfile]]];
    [inTask setArguments:@[masterSqlFileCopy]];
    [inTask launch];
    [inTask waitUntilExit];
    
    [[NSFileManager defaultManager] removeItemAtPath:masterSqlFile error:NULL];
    [[NSFileManager defaultManager] copyItemAtPath:masterSqlFileCopy toPath:masterSqlFile error:NULL];
    
    return YES;
}

+ (BOOL) installExtensionInDirectory:(NSString*)extdir error:(NSError* __autoreleasing*)error {
    NSString* htmlSourceDir = [self htmlDocsDirInExtensionDirectory:extdir];
    NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:htmlSourceDir error:NULL];
    NSString* htmlDestDir = [self sharedHtmlDocsDir];
    
    for (NSString* file in files) {
        [[NSFileManager defaultManager] copyItemAtPath:[htmlSourceDir stringByAppendingPathComponent:file]
                                                toPath:[htmlDestDir stringByAppendingPathComponent:file]
                                                 error:NULL];
    }
    
    [self runSqlFile:@"docs.in.sql" inDir:extdir error:error];
    return YES;
}

+ (BOOL) uninstallExtensionInDirectory:(NSString*)extdir error:(NSError* __autoreleasing*)error {
    [self runSqlFile:@"docs.out.sql" inDir:extdir error:error];
    
    NSString* htmlSourceDir = [self htmlDocsDirInExtensionDirectory:extdir];
    NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:htmlSourceDir error:NULL];
    NSString* htmlDestDir = [self sharedHtmlDocsDir];
    for (NSString* file in files) {
        [[NSFileManager defaultManager] removeItemAtPath:[htmlDestDir stringByAppendingPathComponent:file]
                                                   error:NULL];
    }
    return YES;
}

@end
