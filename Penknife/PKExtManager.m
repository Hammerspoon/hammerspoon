#import "PKExtManager.h"

NSString* PKExtensionsUpdatedNotification = @"PKExtensionsUpdatedNotification";

static NSString* PKMasterShaURL = @"https://api.github.com/repos/penknife-io/ext/git/refs/heads/master";
static NSString* PKTreeListURL  = @"https://api.github.com/repos/penknife-io/ext/git/trees/master";

@implementation PKExtManager

+ (PKExtManager*) sharedExtManager {
    static PKExtManager* sharedExtManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedExtManager = [[PKExtManager alloc] init];
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
                                   if (obj) {
                                       handler(obj);
                                   }
                                   else {
                                       NSLog(@"json error: %@", jsonError);
                                   }
                               }
                               else {
                                   NSLog(@"connection error: %@", connectionError);
                               }
                           }];
}

- (void) update {
    if (self.updating) return;
    self.updating = YES;
    
    [self getURL:PKMasterShaURL handleJSON:^(NSDictionary* json) {
        NSString* newsha = [[json objectForKey:@"object"] objectForKey:@"sha"];
        
        // we need this to get the sha for the rawgithubcontent url (can't just use 'master' in case github's cache fails us)
        // we can also use it to quickly know if we need to fetch the full file dir.
        
        if ([newsha isEqualToString: self.cache.sha]) {
            NSLog(@"no update found.");
            self.updating = NO;
            return;
        }
        
        NSLog(@"update found!");
        
        self.cache.sha = newsha;
        
        [self getURL:PKTreeListURL handleJSON:^(NSDictionary* json) {
            NSMutableArray* newlist = [NSMutableArray array];
            for (NSDictionary* file in [json objectForKey:@"tree"]) {
                NSString* path = [file objectForKey:@"path"];
                if ([path hasSuffix:@".json"])
                    [newlist addObject:@{@"path": path, @"sha": [file objectForKey:@"sha"]}];
            }
            [self reflectAvailableExts:newlist];
            self.updating = NO;
        }];
    }];
}

- (void) reflectAvailableExts:(NSArray*)latestexts {
    // 1. look for all old shas missing from the new batch and delete their represented local files
    // 2. look for all new shas missing from old batch and download their files locally
    
    NSLog(@"in here");
    
    // TODO: only save this after all things are done.
    [self.cache save];
    
//    NSMutableDictionary* newextensions = [self.availableExts mutableCopy];
    
//    NSArray* latestshas = [latestexts valueForKeyPath:@"sha"];
//    for (NSDictionary* oldext in self.availableExts) {
//        if (![latestshas containsObject: [oldext objectForKey:@"sha"]]) {
//            
////            [newextensions removeo
//            
//            NSString* path = [NSString stringWithFormat:[self localFileTemplate], [oldext objectForKey:@"path"]];
//            NSLog(@"deleting old: %@", path);
//            [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
//        }
//    }
//    
//    NSArray* oldshas = [self.availableExts valueForKeyPath:@"sha"];
//    for (NSDictionary* latestext in latestexts) {
//        if (![oldshas containsObject: [latestext objectForKey:@"sha"]]) {
//            NSString* url = [NSString stringWithFormat:PKRawFilePathURLTemplate, self.latestSha, [latestext objectForKey: @"path"]];
//            NSLog(@"downloading new: %@", url);
//            
//            [self getURL:url handleJSON:^(NSDictionary* json) {
//                NSLog(@"%@", json);
//            }];
//            
////            [self downloadURL:url
////                       toPath:[NSString stringWithFormat:[self localFileTemplate], [latestext objectForKey:@"path"]]];
//        }
//    }
//    
//    self.availableExts = latestexts;
//    [self saveExts:self.availableExts to:[self extsAvailableFile]];
//    
//    [[NSNotificationCenter defaultCenter] postNotificationName:PKExtensionsUpdatedNotification object:nil];
}

- (void) setup {
    self.cache = [PKExtensionCache cache];
    [[NSNotificationCenter defaultCenter] postNotificationName:PKExtensionsUpdatedNotification object:nil];
    [self update];
}

@end
