#import "MJExtensionManager.h"
#import "MJExtension.h"
#import "core.h"

NSString* MJExtensionsUpdatedNotification = @"MJExtensionsUpdatedNotification";

static NSString* MJMasterShaURL = @"https://api.github.com/repos/mjolnir-io/ext/git/refs/heads/master";
static NSString* MJTreeListURL  = @"https://api.github.com/repos/mjolnir-io/ext/git/trees/master";
static NSString* MJRawFilePathURLTemplate = @"https://raw.githubusercontent.com/mjolnir-io/ext/%@/%@";

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

- (void) getURL:(NSString*)urlString done:(void(^)(id json, NSError* error))done {
    // come on apple srsly
    NSURL* url = [NSURL URLWithString:urlString];
    NSURLRequest* req = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:5.0];
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               NSString* limitRemaining = [[(NSHTTPURLResponse*)response allHeaderFields] objectForKey:@"X-RateLimit-Remaining"];
                               if (limitRemaining && [limitRemaining integerValue] < 1) {
                                   done(nil, [NSError errorWithDomain:@"Github API"
                                                                 code:0
                                                             userInfo:@{NSLocalizedDescriptionKey: @"Github's API needs time to recover from you."}]);
                               }
                               else if (data) {
                                   NSError* __autoreleasing jsonError;
                                   id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                   if (obj)
                                       done(obj, nil);
                                   else
                                       done(nil, jsonError);
                               }
                               else {
                                   done(nil, connectionError);
                               }
                           }];
}

- (void) update {
    if (self.updating) return;
    self.updating = YES;
    
    [self getURL:MJMasterShaURL done:^(NSDictionary* json, NSError* error) {
        if (error) {
            NSLog(@"%@", error);
            self.updating = NO;
            return;
        }
        
        NSString* newsha = [[json objectForKey:@"object"] objectForKey:@"sha"];
        
        if ([newsha isEqualToString: self.cache.sha]) {
            NSLog(@"no update found.");
            self.updating = NO;
            return;
        }
        
        NSLog(@"update found!");
        
        self.cache.sha = newsha;
        
        [self getURL:MJTreeListURL done:^(NSDictionary* json, NSError* error) {
            if (error) {
                NSLog(@"%@", error);
                self.updating = NO;
                return;
            }
            
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
        
        [self getURL:url done:^(NSDictionary* json, NSError* error) {
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
        
        NSArray* upgradedVersionsOfThis = [extsAvailable filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.name == %@", ext.name]];
        if ([upgradedVersionsOfThis count] == 1) {
            MJExtension* newer = [upgradedVersionsOfThis firstObject];
            newer.previous = ext;
            [extsNeedingUpgrade addObject: newer];
            [extsAvailable removeObject: newer];
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
    for (MJExtension* ext in [install arrayByAddingObjectsFromArray: upgrade]) {
        for (NSString* depname in [ext dependencies]) {
            // TODO: make sure depname is installed somehow
        }
    }
    
    NSMutableArray* errors = [NSMutableArray array];
    dispatch_group_t g = dispatch_group_create();
    dispatch_group_enter(g);
    
    dispatch_group_notify(g, dispatch_get_main_queue(), ^{
        [self.cache save];
        [self rebuildMemoryCache];
        NSLog(@"%@", errors);
        // TODO: present errors to the user
    });
    
    for (MJExtension* ext in uninstall)
        [self uninstall:ext errors:errors group:g];
    
    for (MJExtension* ext in install)
        [self install:ext errors:errors group:g];
    
    for (MJExtension* newext in upgrade)
        [self upgrade:newext errors:errors group:g];
    
    dispatch_group_leave(g);
}

- (void) install:(MJExtension*)ext errors:(NSMutableArray*)errors group:(dispatch_group_t)g {
    dispatch_group_async(g, dispatch_get_main_queue(), ^{
        dispatch_group_enter(g);
        [ext install:^(NSError* err) {
            if (!err)
                [self.cache.extensionsInstalled addObject: ext];
            else
                [errors addObject: err];
            
            dispatch_group_leave(g);
        }];
    });
}

- (void) uninstall:(MJExtension*)ext errors:(NSMutableArray*)errors group:(dispatch_group_t)g {
    dispatch_group_async(g, dispatch_get_main_queue(), ^{
        dispatch_group_enter(g);
        [ext uninstall:^(NSError* err) {
            if (!err)
                [self.cache.extensionsInstalled removeObject: ext];
            else
                [errors addObject: err];
            
            dispatch_group_leave(g);
        }];
    });
}

- (void) upgrade:(MJExtension*)ext errors:(NSMutableArray*)errors group:(dispatch_group_t)g {
    dispatch_group_async(g, dispatch_get_main_queue(), ^{
        dispatch_group_enter(g);
        [ext uninstall:^(NSError* err) {
            if (!err) {
                [self.cache.extensionsInstalled removeObject: ext];
                ext.previous = nil;
                [self install:ext errors:errors group:g];
            }
            else {
                [errors addObject: err];
            }
            dispatch_group_leave(g);
        }];
    });
}

@end
