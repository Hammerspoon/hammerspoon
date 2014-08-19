#import "MJUpdate.h"
#import "MJFileUtils.h"
#import "MJVerifiers.h"
#import "variables.h"

@interface MJUpdate ()
@property NSString* downloadURL;
@property NSString* signature;
@end

@implementation MJUpdate

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

+ (void) checkForUpdate:(void(^)(MJUpdate* updater, NSError* connError))handler {
    MJDownloadFile(MJUpdatesURL, ^(NSError *connectionError, NSData *data) {
        if (!data) {
            handler(nil, connectionError);
            return;
        }
        
        NSString* wholeString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSArray* lines = [wholeString componentsSeparatedByString:@"\n"];
        NSString* versionString = [lines objectAtIndex:0];
        NSString* tgzURL = [lines objectAtIndex:1];
        NSString* signature = [lines objectAtIndex:2];
        
        if (MJVersionFromString(versionString) <= MJCurrentVersion()) {
            handler(nil, nil);
            return;
        }
        
        MJUpdate* updater = [[MJUpdate alloc] init];
        updater.signature = signature;
        updater.downloadURL = tgzURL;
        updater.newerVersion = versionString;
        updater.yourVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
        updater.canAutoInstall = [[NSFileManager defaultManager] isDeletableFileAtPath:[[NSBundle mainBundle] bundlePath]];
        handler(updater, nil);
    });
}

- (void) install:(void(^)(NSString* error, NSString* reason))handler {
    MJDownloadFile(self.downloadURL, ^(NSError *connectionError, NSData *tgzdata) {
        if (!tgzdata) {
            handler(@"Error downloading Mjolnir.tgz", [connectionError localizedDescription]);
            return;
        }
        
        if (!MJVerifySignedData([self.signature dataUsingEncoding:NSUTF8StringEncoding], tgzdata)) {
            handler(@"Mjolnir.tgz failed security verification!", @"DSA signature could not be verified.");
            return;
        }
        
        NSError *__autoreleasing mkTempDirError;
        NSString* tempDirectory = MJCreateEmptyTempDirectory(@"mjolnir-", &mkTempDirError);
        if (!tempDirectory) {
            handler(@"Error creating temporary directory for Mjolnir.tgz", [mkTempDirError localizedDescription]);
            return;
        }
        
        NSError* __autoreleasing untarError;
        BOOL untarSuccess = MJUntar(tgzdata, tempDirectory, &untarError);
        if (!untarSuccess) {
            handler(@"Error extracting Mjolnir.tgz", [untarError localizedDescription]);
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
