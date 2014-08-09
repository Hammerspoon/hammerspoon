#import "MJExtensionManager.h"
#import "MJExtension.h"
#import "MJSHA1Verifier.h"
#import "core.h"

NSString* MJExtensionsUpdatedNotification = @"MJExtensionsUpdatedNotification";

static NSString* MJExtensionsManifestURL = @"https://raw.githubusercontent.com/mjolnir-io/mjolnir-ext/master/manifest.json";

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
    NSURL* url = [NSURL URLWithString:urlString];
    NSURLRequest* req = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:5.0];
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (data) {
                                   NSRange r = [data rangeOfData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]
                                                         options:0
                                                           range:NSMakeRange(0, [data length])];
                                   
                                   NSData* sig = [data subdataWithRange:NSMakeRange(0, r.location)];
                                   NSData* json = [data subdataWithRange:NSMakeRange(NSMaxRange(r), [data length] - NSMaxRange(r))];
                                   
                                   NSLog(@"%@", [[NSString alloc] initWithData:sig encoding:NSUTF8StringEncoding]);
                                   NSLog(@"%d", MJVerifySignedData(sig, json));
                                   
                                   NSError* __autoreleasing jsonError;
                                   id obj = [NSJSONSerialization JSONObjectWithData:json options:0 error:&jsonError];
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
    
    [self getURL:MJExtensionsManifestURL done:^(id json, NSError *error) {
//        NSLog(@"%@", json);
    }];
    
//    [self getURL:MJMasterShaURL done:^(NSDictionary* json, NSError* error) {
//        if (error) {
//            NSLog(@"%@", error);
//            self.updating = NO;
//            return;
//        }
//        
//        NSString* newsha = [[json objectForKey:@"object"] objectForKey:@"sha"];
//        
//        if ([newsha isEqualToString: self.cache.sha]) {
//            NSLog(@"no update found.");
//            self.updating = NO;
//            return;
//        }
//        
//        NSLog(@"update found!");
//        
//        self.cache.sha = newsha;
//        
//        [self getURL:MJTreeListURL done:^(NSDictionary* json, NSError* error) {
//            if (error) {
//                NSLog(@"%@", error);
//                self.updating = NO;
//                return;
//            }
//            
//            NSMutableArray* newlist = [NSMutableArray array];
//            for (NSDictionary* file in [json objectForKey:@"tree"]) {
//                NSString* path = [file objectForKey:@"path"];
//                if ([path hasSuffix:@".json"])
//                    [newlist addObject:@{@"path": path, @"sha": [file objectForKey:@"sha"]}];
//            }
//            [self reflectAvailableExts:newlist];
//        }];
//    }];
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
    
//    for (NSDictionary* ext in additions) {
//        NSString* extNamePath = [ext objectForKey: @"path"];
//        NSString* url = [NSString stringWithFormat:MJExtensionsManifestURL, self.cache.sha, extNamePath];
//        NSLog(@"downloading: %@", url);
//        
//        [self getURL:url done:^(NSDictionary* json, NSError* error) {
//            [self.cache.extensionsAvailable addObject: [MJExtension extensionWithShortJSON:ext longJSON:json]];
//            
//            if (--waitingfor == 0)
//                [self doneUpdating];
//        }];
//    }
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

- (void) upgrade:(NSMutableArray*)toupgrade
         install:(NSMutableArray*)toinstall
       uninstall:(NSMutableArray*)touninstall
{
    // for all extensions that are about to be installed or upgraded:
    for (MJExtension* ext in [toinstall arrayByAddingObjectsFromArray: toupgrade]) {
        // if it has no dependencies, move on to the next one
        if ([ext.dependencies count] == 0)
            continue;
        
        NSPredicate* containsDeps = [NSPredicate predicateWithFormat:@"self.name IN %@", ext.dependencies];
        
        // if any of its dependencies were going to be uninstalled, remove it from that list and move on
        // we know it cant be in any other list, since we know it's already installed
        NSArray* uninstallingDeps = [touninstall filteredArrayUsingPredicate:containsDeps];
        if ([uninstallingDeps count] > 0) {
            [touninstall removeObjectsInArray:uninstallingDeps];
            continue;
        }
        
        // otherwise, if any of its dependencies are going to be installed or upgraded, we're all good, so move on
        if ([[[toinstall arrayByAddingObjectsFromArray:toupgrade] filteredArrayUsingPredicate:containsDeps] count] > 0)
            continue;
        
        // otherwise, if its already installed, we're all good, move on
        if ([[self.cache.extensionsInstalled filteredArrayUsingPredicate:containsDeps] count] > 0)
            continue;
        
        // otherwise, it isnt installed or going to be installed, so add it to the to-be-installed list
        for (MJExtension* ext in [self.cache.extensionsAvailable filteredArrayUsingPredicate:containsDeps])
            [toinstall addObject: ext];
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
    
    for (MJExtension* ext in touninstall)
        [self uninstall:ext errors:errors group:g];
    
    for (MJExtension* ext in toinstall)
        [self install:ext errors:errors group:g];
    
    for (MJExtension* newext in toupgrade)
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
