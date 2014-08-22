#import "MJExtensionManager.h"
#import "MJExtension.h"
#import "MJSecurityUtils.h"
#import "MJLua.h"
#import "variables.h"

NSString* MJExtensionsUpdatedNotification = @"MJExtensionsUpdatedNotification";

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
                                   
                                   if (!MJVerifySignedData(sig, json)) {
                                       done(nil, [NSError errorWithDomain:@"Mjolnir" code:0 userInfo:@{NSLocalizedDescriptionKey: @"manifest.json didn't pass the test"}]);
                                       return;
                                   }
                                   
                                   NSError* __autoreleasing jsonError;
                                   id obj = [NSJSONSerialization JSONObjectWithData:json options:0 error:&jsonError];
                                   if (obj) jsonError = nil;
                                   done(obj, jsonError);
                               }
                               else {
                                   done(nil, connectionError);
                               }
                           }];
}

- (void) update {
    if (self.updating) return;
    self.updating = YES;
    
    [self getURL:MJExtensionsManifestURL done:^(NSDictionary* json, NSError *error) {
        if (error) {
            NSLog(@"%@", error);
            self.updating = NO;
            return;
        }
        
        NSNumber* newtimestamp = [json objectForKey:@"timestamp"];
        if ([newtimestamp unsignedLongValue] <= [self.cache.timestamp unsignedLongValue]) {
            NSLog(@"no update found.");
            self.updating = NO;
            return;
        }
        
        NSLog(@"update found!");
        self.cache.timestamp = newtimestamp;
        
        for (NSDictionary* ext in [json objectForKey: @"extensions"])
            [self.cache.extensionsAvailable addObject: [MJExtension extensionWithJSON:ext]];
        
        [self.cache.extensionsAvailable sortUsingComparator:^NSComparisonResult(MJExtension* a, MJExtension* b) {
            return [a.name compare: b.name];
        }];
        
        [self.cache save];
        [self rebuildMemoryCache];
        
        self.updating = NO;
        NSLog(@"done updating.");
    }];
}

- (void) setup {
    self.cache = [MJExtensionCache cache];
    [self rebuildMemoryCache];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self update];
    });
}

- (void) loadInstalledModules {
    for (MJExtension* ext in self.cache.extensionsInstalled)
        MJLuaLoadModule(ext.name);
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
         handler:(void(^)(NSDictionary* errors))handler
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
    
    NSMutableDictionary* errors = [NSMutableDictionary dictionary];
    dispatch_group_t g = dispatch_group_create();
    dispatch_group_enter(g);
    
    dispatch_group_notify(g, dispatch_get_main_queue(), ^{
        [self.cache save];
        [self rebuildMemoryCache];
        handler(errors);
    });
    
    for (MJExtension* ext in touninstall)
        [self uninstall:ext errors:errors group:g];
    
    for (MJExtension* ext in toinstall)
        [self install:ext errors:errors group:g];
    
    for (MJExtension* newext in toupgrade)
        [self upgrade:newext errors:errors group:g];
    
    dispatch_group_leave(g);
}

- (void) install:(MJExtension*)ext errors:(NSMutableDictionary*)errors group:(dispatch_group_t)g {
    dispatch_group_async(g, dispatch_get_main_queue(), ^{
        dispatch_group_enter(g);
        [ext install:^(NSError* err) {
            if (!err)
                [self.cache.extensionsInstalled addObject: ext];
            else
                [errors setObject:err forKey:ext.name];
            
            dispatch_group_leave(g);
        }];
    });
}

- (void) uninstall:(MJExtension*)ext errors:(NSMutableDictionary*)errors group:(dispatch_group_t)g {
    dispatch_group_async(g, dispatch_get_main_queue(), ^{
        dispatch_group_enter(g);
        [ext uninstall:^(NSError* err) {
            if (!err)
                [self.cache.extensionsInstalled removeObject: ext];
            else
                [errors setObject:err forKey:ext.name];
            
            dispatch_group_leave(g);
        }];
    });
}

- (void) upgrade:(MJExtension*)ext errors:(NSMutableDictionary*)errors group:(dispatch_group_t)g {
    dispatch_group_async(g, dispatch_get_main_queue(), ^{
        dispatch_group_enter(g);
        [ext uninstall:^(NSError* err) {
            if (!err) {
                [self.cache.extensionsInstalled removeObject: ext];
                ext.previous = nil;
                [self install:ext errors:errors group:g];
            }
            else {
                [errors setObject:err forKey:ext.name];
            }
            dispatch_group_leave(g);
        }];
    });
}

@end
