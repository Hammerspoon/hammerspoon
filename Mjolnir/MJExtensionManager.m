#import "MJExtensionManager.h"
#import "MJExtension.h"
#import "MJDocsManager.h"
#import "MJConfigManager.h"
void MJLoadModule(NSString* fullname);

NSString* MJExtensionsUpdatedNotification = @"MJExtensionsUpdatedNotification";

static NSString* MJMasterShaURL = @"https://api.github.com/repos/penknife-io/ext/git/refs/heads/master";
static NSString* MJTreeListURL  = @"https://api.github.com/repos/penknife-io/ext/git/trees/master";
static NSString* MJRawFilePathURLTemplate = @"https://raw.githubusercontent.com/penknife-io/ext/%@/%@";

@interface MJExtensionManager ()
@property MJExtensionCache* cache;
@end

@implementation MJExtensionManager

+ (MJExtensionManager*) sharedManager {
    static MJExtensionManager* sharedExtManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedExtManager = [[MJExtensionManager alloc] init];
    });
    return sharedExtManager;
}

- (void) getURL:(NSString*)urlString handleJSON:(void(^)(id json))handler {
    // come on apple srsly
    NSURL* url = [NSURL URLWithString:urlString];
    NSURLRequest* req = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:5.0];
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (data) {
                                   NSError* __autoreleasing jsonError;
                                   id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                   if (obj)
                                       handler(obj);
                                   else
                                       NSLog(@"json error: %@ - %@", jsonError, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                               }
                               else {
                                   NSLog(@"connection error: %@", connectionError);
                               }
                           }];
}

- (void) update {
    if (self.updating) return;
    self.updating = YES;
    
    [self getURL:MJMasterShaURL handleJSON:^(NSDictionary* json) {
        NSString* newsha = [[json objectForKey:@"object"] objectForKey:@"sha"];
        
        if ([newsha isEqualToString: self.cache.sha]) {
            NSLog(@"no update found.");
            self.updating = NO;
            return;
        }
        
        NSLog(@"update found!");
        
        self.cache.sha = newsha;
        
        [self getURL:MJTreeListURL handleJSON:^(NSDictionary* json) {
            NSMutableArray* newlist = [NSMutableArray array];
            for (NSDictionary* file in [json objectForKey:@"tree"]) {
                NSString* path = [file objectForKey:@"path"];
                if ([path hasSuffix:@".json"])
                    [newlist addObject:@{@"path": path, @"sha": [file objectForKey:@"sha"]}];
            }
            [self reflectAvailableExts:newlist];
        }];
    }];
}

- (void) doneUpdating {
    [self.cache.extensionsAvailable sortUsingComparator:^NSComparisonResult(MJExtension* a, MJExtension* b) {
        return [a.name compare: b.name];
    }];
    
    NSLog(@"done updating.");
    self.updating = NO;
    [self.cache save];
    [self rebuildMemoryCache];
}

- (void) reflectAvailableExts:(NSArray*)latestexts {
    // 1. look for all old shas missing from the new batch and delete their represented local files
    // 2. look for all new shas missing from old batch and download their files locally
    
    NSArray* oldshas = [self.cache.extensionsAvailable valueForKeyPath:@"sha"];
    NSArray* latestshas = [latestexts valueForKeyPath:@"sha"];
    
    NSArray* removals = [self.cache.extensionsAvailable filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT self.sha IN %@", latestshas]];
    NSArray* additions = [latestexts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT sha IN %@", oldshas]];
    
    for (MJExtension* oldext in removals)
        [self.cache.extensionsAvailable removeObject:oldext];
    
    __block NSUInteger waitingfor = [additions count];
    
    if (waitingfor == 0) {
        [self doneUpdating];
        return;
    }
    
    for (NSDictionary* ext in additions) {
        NSString* extNamePath = [ext objectForKey: @"path"];
        NSString* url = [NSString stringWithFormat:MJRawFilePathURLTemplate, self.cache.sha, extNamePath];
        NSLog(@"downloading: %@", url);
        
        [self getURL:url handleJSON:^(NSDictionary* json) {
            [self.cache.extensionsAvailable addObject: [MJExtension extensionWithShortJSON:ext longJSON:json]];
            
            if (--waitingfor == 0)
                [self doneUpdating];
        }];
    }
}

- (void) setup {
    self.cache = [MJExtensionCache cache];
    [self rebuildMemoryCache];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // This also could have been what was sometimes slowing launch down (spinning-rainbow for a few seconds).
        [self update];
    });
}

- (void) loadInstalledModules {
    for (MJExtension* ext in self.cache.extensionsInstalled)
        MJLoadModule(ext.name);
}

- (void) rebuildMemoryCache {
    NSMutableArray* extsAvailable = [self.cache.extensionsAvailable mutableCopy];
    NSMutableArray* extsUpToDate = [NSMutableArray array];
    NSMutableArray* extsNeedingUpgrade = [NSMutableArray array];
    NSMutableArray* extsRemovedRemotely = [NSMutableArray array];
    
    for (MJExtension* ext in self.cache.extensionsInstalled) {
        if ([extsAvailable containsObject: ext]) {
            [extsUpToDate addObject: ext];
            [extsAvailable removeObject: ext];
            continue;
        }
        
        NSArray* upgradedVersionsOfThis = [extsAvailable filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.sha == %@", ext.sha]];
        if ([upgradedVersionsOfThis count] == 1) {
            [extsNeedingUpgrade addObject: ext];
            [extsAvailable removeObject: ext];
            continue;
        }
        
        [extsRemovedRemotely addObject: ext];
        [extsAvailable removeObject: ext];
    }
    
    self.extsNotInstalled = extsAvailable;
    self.extsUpToDate = extsUpToDate;
    self.extsNeedingUpgrade = extsNeedingUpgrade;
    self.extsRemovedRemotely = extsRemovedRemotely;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MJExtensionsUpdatedNotification object:nil];
}

- (void) upgrade:(NSArray*)upgrade
         install:(NSArray*)install
       uninstall:(NSArray*)uninstall
{
    for (MJExtension* ext in upgrade)
        [self upgrade: ext];
    
    for (MJExtension* ext in install)
        [self install: ext];
    
    for (MJExtension* ext in uninstall)
        [self uninstall: ext];
    
    [self.cache save];
    [self rebuildMemoryCache];
}

- (void) install:(MJExtension*)ext {
    [self.cache.extensionsInstalled addObject: ext];
    
    // order matters
    [MJConfigManager installExtension:ext];
    [MJDocsManager installExtension:ext];
}

- (void) upgrade:(MJExtension*)oldext {
    MJExtension* newext = [[self.cache.extensionsAvailable filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name == %@", oldext.name]] firstObject];
    [self uninstall:oldext];
    [self install:newext];
}

- (void) uninstall:(MJExtension*)ext {
    [self.cache.extensionsInstalled removeObject: ext];
    
    // order matters
    [MJDocsManager uninstallExtension:ext];
    [MJConfigManager uninstallExtension:ext];
}

@end
