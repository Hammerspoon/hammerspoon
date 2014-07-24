#import "HydraLicense.h"
#import <CommonCrypto/CommonDigest.h>
#import "HydraLicenseRequester.h"

#define HYDRA_LICENSE_INITIAL_DELAY (60 * 60 * 3)
#define HYDRA_LICENSE_DELAY         (60 * 60 * 5)

static NSString* hydra_pubkey = @"-----BEGIN PUBLIC KEY-----\n"
"MIHwMIGoBgcqhkjOOAQBMIGcAkEAzKaHbgkiRpZB2tz2hUpk7Y7icIh3Zd5Vi086\n"
"tVK9vcp+1e9zU6lNvW1nM0rNJzGWWWLCKsNvXxaoPQUOib7k1wIVAK/W4Zv5zFz1\n"
"UsFaKF6jz2xDkFCNAkBCuPlrBeNgFi9LeCre5ZRvV1DUpvPcB4/HdIZNznOJTAUq\n"
"URuCB6su1gBBOTa82TfI2YyF0Sp5kKV0oLHWD69VA0MAAkBz3WE0WorE8zgVvupR\n"
"/qwIw/J+ANM+kuxHuBg2gaweTRsFFy6b6gHZHWndKl3lEUZhz/CFxHwOgg081yY/\n"
"1da2\n"
"-----END PUBLIC KEY-----\n";

static void createpublickey(NSString* publkeyString, SecKeyRef* keyptr, CFErrorRef* errorptr) {
    CFDataRef privkeyData = (__bridge CFDataRef)[publkeyString dataUsingEncoding:NSUTF8StringEncoding];
    SecExternalItemType itemType = kSecItemTypePublicKey;
    SecExternalFormat externalFormat = kSecFormatPEMSequence;
    int flags = 0;
    
    SecItemImportExportKeyParameters params = {0};
    params.version = SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION;
    params.flags = 0;
    
    CFArrayRef items = NULL;
    OSStatus oserr = SecItemImport(privkeyData, NULL, &externalFormat, &itemType, flags, &params, NULL, &items);
    if (oserr)
        *errorptr = CFErrorCreate(NULL, kCFErrorDomainOSStatus, oserr, NULL);
    else if (items)
        *keyptr = (SecKeyRef)CFRetain(CFArrayGetValueAtIndex(items, 0));
    
    if (items)
        CFRelease(items);
}

BOOL hydra_verifylicense(NSString* pubkey, NSString* sig, NSString* email) {
    if ([pubkey length] == 0 || [sig length] == 0 || [email length] == 0)
        return NO;
    
    NSMutableString *transformedEmail = [NSMutableString string];
    for (NSInteger i = [email length] - 1; i >= 0; i--)
        [transformedEmail appendFormat:@"%c", [email characterAtIndex:i]];
    
    BOOL result = NO;
    NSData* sigData = [[NSData alloc] initWithBase64EncodedString:sig options:0];
    CFErrorRef error = NULL;
    SecKeyRef publickey = NULL;
    
    createpublickey(pubkey, &publickey, &error);
    if (error) goto cleanup;
    
    SecTransformRef verifier = SecVerifyTransformCreate(publickey, (__bridge CFDataRef)sigData, &error);
    if (error) goto cleanup;
    
    CFDataRef emailDataToVerify = (__bridge CFDataRef)[transformedEmail dataUsingEncoding:NSUTF8StringEncoding];
    SecTransformSetAttribute(verifier, kSecTransformInputAttributeName, emailDataToVerify, &error);
    if (error) goto cleanup;
    
    result = [(__bridge NSNumber*)SecTransformExecute(verifier, &error) boolValue];
    
cleanup:
    if (publickey) CFRelease(publickey);
    if (verifier) CFRelease(verifier);
    if (error) { CFShow(error); CFRelease(error); }
    return result;
}

#define HydraEmailKey @"_HydraEmail"
#define HydraLicenseKey @"_HydraLicense"

@interface HydraLicense () <HydraLicenseRequesterDelegate>
@property HydraLicenseRequester* requester;
@end

@implementation HydraLicense

- (NSString*) storedEmail {
    return [[NSUserDefaults standardUserDefaults] stringForKey:HydraEmailKey];
}

- (NSString*) storedLicense {
    return [[NSUserDefaults standardUserDefaults] stringForKey:HydraLicenseKey];
}

- (BOOL) hasLicense {
    return hydra_verifylicense(hydra_pubkey, [self storedLicense], [self storedEmail]);
}

- (HydraLicenseRequester*) lazyLoadedRequester {
    if (!self.requester) {
        self.requester = [[HydraLicenseRequester alloc] init];
        self.requester.delegate = self;
    }
    return self.requester;
}

- (void) initialCheck {
    [self performSelector:@selector(check) withObject:nil afterDelay:HYDRA_LICENSE_INITIAL_DELAY];
}

- (void) check {
    if ([self hasLicense])
        return;
    
    [[self lazyLoadedRequester] request];
    [self performSelector:@selector(check) withObject:nil afterDelay:HYDRA_LICENSE_DELAY];
}

- (BOOL) tryLicense:(NSString*)license forEmail:(NSString*)email {
    BOOL valid = hydra_verifylicense(hydra_pubkey, license, email);
    
    if (valid) {
        [[NSUserDefaults standardUserDefaults] setObject:email forKey:HydraEmailKey];
        [[NSUserDefaults standardUserDefaults] setObject:license forKey:HydraLicenseKey];
        [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(check) object:nil];
    }
    
    return valid;
}

- (void) enter {
    [[self lazyLoadedRequester] request];
    [[[self lazyLoadedRequester] window] makeKeyWindow];
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
}

- (void) closed {
    self.requester = nil;
}

@end
