#import "PKExtManager.h"

@implementation PKExtManager

+ (PKExtManager*) sharedExtManager {
    static PKExtManager* sharedExtManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedExtManager = [[PKExtManager alloc] init];
    });
    return sharedExtManager;
}

- (NSString*) extcacheDir { return [@"~/.penknife/.extcache/" stringByStandardizingPath]; }
- (NSString*) extsAvailableFile { return [@"~/.penknife/.extcache/exts.available.json" stringByStandardizingPath]; }
- (NSString*) extsInstalledFile { return [@"~/.penknife/.extcache/exts.isntalled.json" stringByStandardizingPath]; }

- (void) setupPaths {
    NSError* __autoreleasing error;
    BOOL success =
    [[NSFileManager defaultManager] createDirectoryAtPath:[self extcacheDir]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    if (success) {
        NSLog(@"could not create extcache dir: %@", error);
    }
}

- (void) updateExtsAvailableFiles {
    // TOOD: get old copy first; then compare on disk.
    // NOTE: we may not have an old copy, if this is the first time.
    
    NSString* treeListURL = @"https://api.github.com/repos/penknife-io/ext/git/trees/master";
    NSURL* url = [NSURL URLWithString:treeListURL];
    NSURLRequest* req = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:5.0];
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               NSError* __autoreleasing error;
                               NSDictionary* currentTree = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                               if (currentTree) {
                                   NSArray* tree = [currentTree objectForKey:@"tree"];
                                   for (NSDictionary* file in tree) {
                                       NSString* path = [file objectForKey:@"path"];
                                       if (![path hasSuffix:@".json"])
                                           continue;
                                       
                                       NSLog(@"tree: %@", file);
                                       // TODO: grab the json file's name and its sha; then do the normal comparison process.
                                   }
                               }
                           }];
}

- (void) createExtsInstalledFile {
    NSError* __autoreleasing error;
    NSData* data = [NSJSONSerialization dataWithJSONObject:@[] options:NSJSONWritingPrettyPrinted error:&error];
    
    if (!data) {
        NSLog(@"could not serialize json: %@", error);
    }
    
    [data writeToFile:[self extsInstalledFile] atomically:YES];
}

- (void) createFilesIfNeeded {
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self extsAvailableFile]])
        [self updateExtsAvailableFiles];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self extsInstalledFile]])
        [self createExtsInstalledFile];
}

- (void) loadFiles {
    NSError* __autoreleasing error;
    self.installedExts = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[self extsInstalledFile]] options:0 error:&error];
    self.availableExts = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[self extsAvailableFile]] options:0 error:&error];
}

- (void) setup {
    [self setupPaths];
    [self createFilesIfNeeded];
    [self loadFiles];
}

- (void) updateAvailableExts {
    [self updateExtsAvailableFiles];
}

@end
