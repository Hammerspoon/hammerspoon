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

+ (NSString*) copyToTempFile:(NSString*)originalpath {
    const char* tempFileTemplate = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"ext.XXXXXX.tgz"] fileSystemRepresentation];
    char* tempFileName = malloc(strlen(tempFileTemplate) + 1);
    strcpy(tempFileName, tempFileTemplate);
    int fd = mkstemps(tempFileName, 4);
    if (fd == -1) {
        NSLog(@"%@", [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil]);
        return nil;
    }
    NSString* tempFilePath = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:tempFileName length:strlen(tempFileName)];
    free(tempFileName);
    
    NSFileHandle* tempFileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd];
    [tempFileHandle writeData:[NSData dataWithContentsOfFile:originalpath]];
    [tempFileHandle closeFile];
    
    return tempFilePath;
}

+ (NSString*) sharedHtmlDocsDir {
    return [[[self docsFile] URLByAppendingPathComponent:@"Contents/Resources/Documents"] path];
}

+ (NSString*) htmlDocsDirInExtensionDirectory:(NSString*)extdir {
    return [extdir stringByAppendingPathComponent:@"docs.html.d"];
}

+ (void) runSqlFile:(NSString*)sqlfile inDir:(NSString*)extdir {
    NSString* masterSqlFile = [self sqlFile];
    NSString* masterSqlFileCopy = [self copyToTempFile:[self sqlFile]];
    
    NSTask* inTask = [[NSTask alloc] init];
    [inTask setLaunchPath:@"/usr/bin/sqlite3"];
    [inTask setStandardInput:[NSFileHandle fileHandleForReadingAtPath:[extdir stringByAppendingPathComponent:sqlfile]]];
    [inTask setArguments:@[masterSqlFileCopy]];
    [inTask launch];
    [inTask waitUntilExit];
    
    [[NSFileManager defaultManager] removeItemAtPath:masterSqlFile error:NULL];
    [[NSFileManager defaultManager] copyItemAtPath:masterSqlFileCopy toPath:masterSqlFile error:NULL];
}

+ (void) installExtensionInDirectory:(NSString*)extdir {
    NSString* htmlSourceDir = [self htmlDocsDirInExtensionDirectory:extdir];
    NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:htmlSourceDir error:NULL];
    NSString* htmlDestDir = [self sharedHtmlDocsDir];
    
    for (NSString* file in files) {
        [[NSFileManager defaultManager] copyItemAtPath:[htmlSourceDir stringByAppendingPathComponent:file]
                                                toPath:[htmlDestDir stringByAppendingPathComponent:file]
                                                 error:NULL];
    }
    
    NSLog(@"in here");
    
    [self runSqlFile:@"docs.in.sql" inDir:extdir];
}

+ (void) uninstallExtensionInDirectory:(NSString*)extdir {
    [self runSqlFile:@"docs.out.sql" inDir:extdir];
    
    NSString* htmlSourceDir = [self htmlDocsDirInExtensionDirectory:extdir];
    NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:htmlSourceDir error:NULL];
    NSString* htmlDestDir = [self sharedHtmlDocsDir];
    for (NSString* file in files) {
        NSString* dest = [htmlDestDir stringByAppendingPathComponent:file];
        [[NSFileManager defaultManager] removeItemAtPath:dest error:NULL];
    }
}

@end
