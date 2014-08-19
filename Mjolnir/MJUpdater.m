#import "MJUpdater.h"
#import "MJFileUtils.h"
#import "MJVerifiers.h"

static NSString* MJUpdatesURL = @"https://raw.githubusercontent.com/mjolnir-io/mjolnir/master/LATESTVERSION";

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
    MJDownloadFile(MJUpdatesURL, ^(NSError *connectionError, NSData *data) {
        if (!data) {
            NSLog(@"error looking for new Mjolnir release: %@", connectionError);
            handler(nil);
            return;
        }
        
        NSString* wholeString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSArray* lines = [wholeString componentsSeparatedByString:@"\n"];
        NSString* versionString = [lines objectAtIndex:0];
        NSString* tgzURL = [lines objectAtIndex:1];
        NSString* signature = [lines objectAtIndex:2];
        
        if (MJVersionFromString(versionString) <= MJCurrentVersion()) {
            NSLog(@"no new Mjolnir update");
            handler(nil);
            return;
        }
        
        MJUpdater* updater = [[MJUpdater alloc] init];
        updater.signature = signature;
        updater.downloadURL = tgzURL;
        updater.newerVersion = versionString;
        updater.yourVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
        updater.canAutoInstall = [[NSFileManager defaultManager] isDeletableFileAtPath:[[NSBundle mainBundle] bundlePath]];
        handler(updater);
    });
}

- (void) install:(void(^)(NSString* error, NSString* reason))handler {
    MJDownloadFile(self.downloadURL, ^(NSError *connectionError, NSData *tgzdata) {
        if (!tgzdata) {
            handler(@"Error downloading new Mjolnir release", [connectionError localizedDescription]);
            return;
        }
        
        if (!MJVerifySignedData([self.signature dataUsingEncoding:NSUTF8StringEncoding], tgzdata)) {
            handler(@"newer Mjolnir release doesn't verify!", @"DSA signature did not match.");
            return;
        }
        
        NSError *__autoreleasing mkTempDirError;
        NSString* tempDirectory = MJCreateEmptyTempDirectory(@"mjolnir-", &mkTempDirError);
        if (!tempDirectory) {
            handler(@"Error extracting Mjolnir release", [mkTempDirError localizedDescription]);
            return;
        }
        
        NSError* __autoreleasing untarError;
        
        BOOL untarSuccess = MJUntar(tgzdata, tempDirectory, &untarError);
        if (!untarSuccess) {
            handler(@"Error updating Mjolnir release", [untarError localizedDescription]);
            return;
        }
        
        NSString* thispath = [[NSBundle mainBundle] bundlePath];
        NSString* newpath = [tempDirectory stringByAppendingPathComponent:@"Mjolnir.app"];
        NSString* pidstring = [NSString stringWithFormat:@"%d", getpid()];
        
        NSTask* task = [[NSTask alloc] init];
        [task setLaunchPath:[[NSBundle mainBundle] pathForResource:@"MjolnirRestarter" ofType:@""]];
        [task setArguments:@[pidstring, thispath, newpath]];
        [task launch];
        exit(0);
    });
}

@end
