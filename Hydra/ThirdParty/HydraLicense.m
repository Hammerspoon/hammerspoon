#import "HydraLicense.h"
#include <CommonCrypto/CommonDigest.h>

static NSString* pubkey = @"-----BEGIN PUBLIC KEY-----\n"
"MIHwMIGoBgcqhkjOOAQBMIGcAkEAhUA4RrIEKnAT0J2ZW/fWT9zT4GBVFVQxq+NV\n"
"yk8eqiNdJXF4Y6VMnuohvMA6niQGdgKgwDmg7NTD26kZpyhB4wIVAOQjzXwOopx7\n"
"fol961QqxK/PJSDlAkBILOfA5fupc/jg6SdgUmwWmlAurRoCmZHEn8JZ62zxUy3I\n"
"7TNOSacpXeqw8ypeTFuJH63zCziQdUhTQEGRHDeCA0MAAkBdlN7MK6Rq90GN7yj6\n"
"Us6JTKJm+x/GANMJVvhX9JL49RhXpx46HMs4tWG83XtC6+wjGFssIRuvnv2vbkWp\n"
"y0k5\n"
"-----END PUBLIC KEY-----\n";

static SecKeyRef getpublickey(void) {
    CFDataRef privkeyData = CFBridgingRetain([pubkey dataUsingEncoding:NSUTF8StringEncoding]);
    SecExternalItemType itemType = kSecItemTypePublicKey;
    SecExternalFormat externalFormat = kSecFormatPEMSequence;
    int flags = 0;
    
    SecItemImportExportKeyParameters params;
    params.version = SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION;
    params.flags = 0; // See SecKeyImportExportFlags for details.
    params.passphrase = NULL;
    params.alertTitle = NULL;
    params.alertPrompt = NULL;
    params.accessRef = NULL;
    params.keyUsage = NULL;
    params.keyAttributes = NULL;
    params.keyUsage = NULL;
    params.keyAttributes = NULL;
    
    CFArrayRef items = NULL;
    OSStatus oserr = SecItemImport(privkeyData, NULL, &externalFormat, &itemType, flags, &params, NULL, &items);
    if (oserr) {
        fprintf(stderr, "SecItemImport failed (oserr=%d)\n", oserr);
        CFShow(items);
        exit(-1);
    }
    SecKeyRef key = (SecKeyRef)CFRetain(CFArrayGetValueAtIndex(items, 0));
    return key;
    
//    static SecKeyRef key = NULL;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        SecExternalFormat format = kSecFormatOpenSSL;
//        SecExternalItemType itemType = kSecItemTypePublicKey;
//        SecItemImportExportKeyParameters parameters = {};
//        CFArrayRef items = NULL;
//        CFDataRef privkeyData = (__bridge CFDataRef)[pubkey dataUsingEncoding:NSUTF8StringEncoding];
//        SecItemImport(privkeyData, CFSTR(".pem"), &format, &itemType, 0, &parameters, NULL, &items);
//        key = (SecKeyRef)CFRetain(CFArrayGetValueAtIndex(items, 0));
//    });
//    return key;
}

static BOOL verifylicense(NSString* sig, NSString* emailImmutable) {
    NSData* sigd = [[NSData alloc] initWithBase64EncodedString:sig options:0];
    
    NSMutableString *email = [NSMutableString string];
    for (NSInteger i = [emailImmutable length] - 1; i >= 0; i--)
        [email appendFormat:@"%c", [emailImmutable characterAtIndex:i]];
    
    CFErrorRef error = NULL;
    SecKeyRef security_pubkey = getpublickey();
    SecTransformRef verifier = SecVerifyTransformCreate(security_pubkey, (__bridge CFDataRef)sigd, &error);
    if (error) NSLog(@"crap 1");
    
    CFDataRef emailDataToVerify = (__bridge CFDataRef)[email dataUsingEncoding:NSUTF8StringEncoding];
    SecTransformSetAttribute(verifier, kSecTransformInputAttributeName, emailDataToVerify, &error);
    if (error) NSLog(@"crap 2");
    
    NSNumber* result = (__bridge NSNumber*)SecTransformExecute(verifier, &error);
    return [result boolValue];
}

#define HydraEmailKey @"HydraEmail"
#define HydraLicenseKey @"HydraLicense"

@implementation HydraLicense

- (NSString*) email {
    return [[NSUserDefaults standardUserDefaults] stringForKey:HydraEmailKey];
}

- (NSString*) license {
    return [[NSUserDefaults standardUserDefaults] stringForKey:HydraLicenseKey];
}

- (BOOL) verify {
    return verifylicense([self license], [self email]);
}

- (BOOL) isValid {
    return [self email] && [self license] && [self verify];
}

- (void) check {
    NSLog(@"%d", verifylicense(@"MC0CFQCcGckU7tNoN8H4IbyraKpEDedf4AIUV/7au5+vvtuorcvHJCY436BVPeY=", @"vagif.samadoghlu@example.com"));
}

@end
