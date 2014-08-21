#import "MJDocsManager.h"
#import "MJConfigManager.h"
#import "MJFileUtils.h"

static NSString* master_sql_file(void) {
    return [[MJDocsFile() URLByAppendingPathComponent:@"Contents/Resources/docSet.dsidx"] path];
}

static NSString* shared_html_docs_dir(void) {
    return [[MJDocsFile() URLByAppendingPathComponent:@"Contents/Resources/Documents"] path];
}

static NSString* html_docs_dir_in_extension_directory(NSString* extdir) {
    return [extdir stringByAppendingPathComponent:@"docs.html.d"];
}

static BOOL run_sql_file(NSString* sqlfile, NSString* extdir, NSError* __autoreleasing* error) {
    NSData* masterSqlFileData = [NSData dataWithContentsOfFile:master_sql_file() options:0 error:error];
    NSString* _masterSqlFile = master_sql_file();
    
    NSString* masterSqlFileCopy = MJWriteToTempFile(masterSqlFileData, @"master.", @".sql", error);
    
    NSTask* inTask = [[NSTask alloc] init];
    [inTask setLaunchPath:@"/usr/bin/sqlite3"];
    [inTask setStandardInput:[NSFileHandle fileHandleForReadingAtPath:[extdir stringByAppendingPathComponent:sqlfile]]];
    [inTask setArguments:@[masterSqlFileCopy]];
    [inTask launch];
    [inTask waitUntilExit];
    
    [[NSFileManager defaultManager] removeItemAtPath:_masterSqlFile error:NULL];
    [[NSFileManager defaultManager] copyItemAtPath:masterSqlFileCopy toPath:_masterSqlFile error:NULL];
    
    return YES;
}

NSURL* MJDocsFile(void) {
    return [NSURL fileURLWithPath:[[MJConfigManager configPath] stringByAppendingPathComponent:@"Mjolnir.docset"]];
}

void MJDocsCopyIfNeeded(void) {
    if ([[NSFileManager defaultManager] fileExistsAtPath:[MJDocsFile() path]])
        return;
    
    NSURL* docsetSourceURL = [[NSBundle mainBundle] URLForResource:@"Mjolnir" withExtension:@"docset"];
    [[NSFileManager defaultManager] copyItemAtURL:docsetSourceURL toURL:MJDocsFile() error:NULL];
}

BOOL MJDocsInstall(NSString* extdir, NSError* __autoreleasing* error) {
    NSString* htmlSourceDir = html_docs_dir_in_extension_directory(extdir);
    NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:htmlSourceDir error:NULL];
    NSString* htmlDestDir = shared_html_docs_dir();
    
    for (NSString* file in files) {
        [[NSFileManager defaultManager] copyItemAtPath:[htmlSourceDir stringByAppendingPathComponent:file]
                                                toPath:[htmlDestDir stringByAppendingPathComponent:file]
                                                 error:NULL];
    }
    
    run_sql_file(@"docs.in.sql", extdir, error);
    return YES;
}

BOOL MJDocsUninstall(NSString* extdir, NSError* __autoreleasing* error) {
    run_sql_file(@"docs.out.sql", extdir, error);
    
    NSString* htmlSourceDir = html_docs_dir_in_extension_directory(extdir);
    NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:htmlSourceDir error:NULL];
    NSString* htmlDestDir = shared_html_docs_dir();
    for (NSString* file in files) {
        [[NSFileManager defaultManager] removeItemAtPath:[htmlDestDir stringByAppendingPathComponent:file]
                                                   error:NULL];
    }
    return YES;
}
