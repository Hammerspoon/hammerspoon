#import "PKExtensionManager.h"
#import "PKExtension.h"

NSString* PKExtensionsUpdatedNotification = @"PKExtensionsUpdatedNotification";

static NSString* PKMasterShaURL = @"https://api.github.com/repos/penknife-io/ext/git/refs/heads/master";
static NSString* PKTreeListURL  = @"https://api.github.com/repos/penknife-io/ext/git/trees/master";
static NSString* PKRawFilePathURLTemplate = @"https://raw.githubusercontent.com/penknife-io/ext/%@/%@";

@implementation PKExtensionManager

+ (PKExtensionManager*) sharedManager {
    static PKExtensionManager* sharedExtManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedExtManager = [[PKExtensionManager alloc] init];
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
                                       NSLog(@"json error: %@", jsonError);
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
        }];
    }];
}

- (void) doneUpdating {
    [self.cache.extensionsAvailable sortUsingComparator:^NSComparisonResult(PKExtension* a, PKExtension* b) {
        return [a.name compare: b.name];
    }];
    
    NSLog(@"done updating.");
    self.updating = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:PKExtensionsUpdatedNotification object:nil];
    [self.cache save];
}

- (void) reflectAvailableExts:(NSArray*)latestexts {
    // 1. look for all old shas missing from the new batch and delete their represented local files
    // 2. look for all new shas missing from old batch and download their files locally
    
    NSArray* oldshas = [self.cache.extensionsAvailable valueForKeyPath:@"sha"];
    NSArray* latestshas = [latestexts valueForKeyPath:@"sha"];
    
    NSArray* removals = [self.cache.extensionsAvailable filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT self.sha IN %@", latestshas]];
    NSArray* additions = [latestexts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT sha IN %@", oldshas]];
    
    for (PKExtension* oldext in removals)
        [self.cache.extensionsAvailable removeObject:oldext];
    
    __block NSUInteger waitingfor = [additions count];
    
    if (waitingfor == 0) {
        [self doneUpdating];
        return;
    }
    
    for (NSDictionary* ext in additions) {
        NSString* extNamePath = [ext objectForKey: @"path"];
        NSString* url = [NSString stringWithFormat:PKRawFilePathURLTemplate, self.cache.sha, extNamePath];
        NSLog(@"downloading: %@", url);
        
        [self getURL:url handleJSON:^(NSDictionary* json) {
            [self.cache.extensionsAvailable addObject: [PKExtension extensionWithShortJSON:ext longJSON:json]];
            
            if (--waitingfor == 0)
                [self doneUpdating];
        }];
    }
}

- (void) setup {
    self.cache = [PKExtensionCache cache];
    [[NSNotificationCenter defaultCenter] postNotificationName:PKExtensionsUpdatedNotification object:nil];
    [self update];
}

@end
