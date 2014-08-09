#import "MJUpdater.h"
#import "MJFileDownloader.h"
#import "MJSHA1Verifier.h"
#import "MJArchiveManager.h"

static NSString* MJUpdatesURL = @"https://api.github.com/repos/mjolnir-io/mjolnir/releases";

@interface MJUpdater ()
@property NSString* downloadURL;
@property NSString* signature;
@end

@implementation MJUpdater

int MJCurrentVersion(void) {
    NSString* ver = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    return MJVersionFromString(ver);
}

int MJVersionFromString(NSString* str) {
    NSScanner* scanner = [NSScanner scannerWithString:str];
    int major;
    int minor;
    int bugfix = 0;
    [scanner scanInt:&major];
    [scanner scanString:@"." intoString:NULL];
    [scanner scanInt:&minor];
    if ([scanner scanString:@"." intoString:NULL]) {
        [scanner scanInt:&bugfix];
    }
    return major * 10000 + minor * 100 + bugfix;
}

+ (void) checkForUpdate:(void(^)(MJUpdater* updater))handler {
    NSLog(@"testing...");
    
    [MJFileDownloader downloadFile:MJUpdatesURL handler:^(NSError *connectionError, NSData *data) {
        if (!data) {
            NSLog(@"error looking for new Mjolnir release: %@", connectionError);
            handler(nil);
            return;
        }
        
        NSError* __autoreleasing jsonError;
        NSArray* releases = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (!releases) {
            NSLog(@"error parsing JSON when checking for new Mjolnir release: %@", jsonError);
        }
        
        NSDictionary* newerRelease = nil;
        for (NSDictionary* release in releases) {
            NSString* versionString = [release objectForKey:@"tag_name"];
            if (MJVersionFromString(versionString) > MJCurrentVersion()) {
                newerRelease = release;
                break;
            }
        }
        
        if (!newerRelease) {
            NSLog(@"no new Mjolnir update");
            handler(nil);
            return;
        }
        
        NSDictionary* tgzAsset = nil;
        NSArray* assets = [newerRelease objectForKey:@"assets"];
        for (NSDictionary* asset in assets) {
            NSString* name = [asset objectForKey:@"name"];
            if ([name hasSuffix:@".tgz"]) {
                tgzAsset = asset;
                break;
            }
        }
        
        if (!tgzAsset) {
            NSLog(@"newer Mjolnir release doesn't have .tgz for some reason");
            handler(nil);
            return;
        }
        
        NSString* body = [newerRelease objectForKey:@"body"];
        
        MJUpdater* updater = [[MJUpdater alloc] init];
        updater.signature = [[body componentsSeparatedByString:@"\n"] lastObject];
        updater.downloadURL = [tgzAsset objectForKey: @"browser_download_url"];
        updater.releaseNotes = body;
        updater.newerVersion = [newerRelease objectForKey:@"tag_name"];
        updater.yourVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
        handler(updater);
    }];
}

- (void) install:(void(^)(NSString* error, NSString* reason))handler {
    [MJFileDownloader downloadFile:self.downloadURL handler:^(NSError *connectionError, NSData *tgzdata) {
        if (!tgzdata) {
            handler(@"Error downloading new Mjolnir release", [connectionError localizedDescription]);
            return;
        }
        
        if (!MJVerifySignedData([self.signature dataUsingEncoding:NSUTF8StringEncoding], tgzdata)) {
            handler(@"newer Mjolnir release doesn't verify!", @"DSA signature did not match.");
            return;
        }
        
        NSString* thispath = [[NSBundle mainBundle] bundlePath];
        NSString* thisparentdir = [thispath stringByDeletingLastPathComponent];
        
        NSError* __autoreleasing rmError;
        [[NSFileManager defaultManager] removeItemAtPath:thispath error:&rmError];
        
        NSError* __autoreleasing untarError;
        [MJArchiveManager untarData:tgzdata intoDirectory:thisparentdir error:&untarError];
        
        NSTask* task = [[NSTask alloc] init];
        [task setLaunchPath:[[NSBundle mainBundle] pathForResource:@"MjolnirRestarter" ofType:@""]];
        [task setArguments:@[thispath, [NSString stringWithFormat:@"%d", getpid()]]];
        [task launch];
        exit(0);
    }];
}

@end
