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

- (void) setupPaths {
    NSError* __autoreleasing error;
    BOOL success =
    [[NSFileManager defaultManager] createDirectoryAtPath:[@"~/.penknife/.extcache/" stringByStandardizingPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    if (success) {
        NSLog(@"could not create .extcache :'(");
    }
}

- (void) createFilesIfNeeded {
    
}

- (void) loadFiles {
}

- (void) saveFiles {
    
}

- (void) appIsQuitting:(NSNotification*)note {
    [self saveFiles];
}

- (void) saveFilesOnQuit {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appIsQuitting:)
                                                 name:NSApplicationWillTerminateNotification
                                               object:nil];
}

- (void) setup {
    [self setupPaths];
    [self createFilesIfNeeded];
    [self loadFiles];
    [self saveFilesOnQuit];
}

- (NSArray*) availableExts {
    return nil;
}

- (NSArray*) installedExts {
    return nil;
}

- (NSArray*) allExts {
    return nil;
}

- (void) updateAvailableExts {
    
}

@end
