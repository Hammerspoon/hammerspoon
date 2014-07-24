#import "HydraLicense.h"
#include <CommonCrypto/CommonDigest.h>

static const char* pubkey = "-----BEGIN PUBLIC KEY-----\n"
"MIHwMIGoBgcqhkjOOAQBMIGcAkEAhUA4RrIEKnAT0J2ZW/fWT9zT4GBVFVQxq+NV\n"
"yk8eqiNdJXF4Y6VMnuohvMA6niQGdgKgwDmg7NTD26kZpyhB4wIVAOQjzXwOopx7\n"
"fol961QqxK/PJSDlAkBILOfA5fupc/jg6SdgUmwWmlAurRoCmZHEn8JZ62zxUy3I\n"
"7TNOSacpXeqw8ypeTFuJH63zCziQdUhTQEGRHDeCA0MAAkBdlN7MK6Rq90GN7yj6\n"
"Us6JTKJm+x/GANMJVvhX9JL49RhXpx46HMs4tWG83XtC6+wjGFssIRuvnv2vbkWp\n"
"y0k5\n"
"-----END PUBLIC KEY-----\n";

static SecKeyRef create_public_key(void) {
    CFArrayRef items = NULL;
    SecKeyRef security_key = NULL;
    
    NSData* privkeyData = [[NSString stringWithUTF8String:pubkey] dataUsingEncoding:NSUTF8StringEncoding];
    if ([privkeyData length] == 0) goto cleanup;
    
    SecExternalFormat format = kSecFormatOpenSSL;
    SecExternalItemType itemType = kSecItemTypePublicKey;
    SecItemImportExportKeyParameters parameters = {};
    
    OSStatus status = SecItemImport((__bridge CFDataRef)privkeyData, NULL, &format, &itemType, 0, &parameters, NULL, &items);
    
    if (status != noErr) { printf("invalid status: %d\n", status); goto cleanup; }
    if (items == NULL) { printf("items were unexpectedly null\n"); goto cleanup; }
    if (format != kSecFormatOpenSSL) { printf("format isn't kSecFormatOpenSSL: %d\n", format); goto cleanup; }
    if (itemType != kSecItemTypePublicKey) { printf("item type isn't kSecItemTypePublicKey: %d\n", itemType); goto cleanup; }
    if (CFArrayGetCount(items) != 1) { printf("items count isn't 1, it's: %ld\n", CFArrayGetCount(items)); goto cleanup; }
    
    security_key = (SecKeyRef)CFRetain(CFArrayGetValueAtIndex(items, 0));
    
cleanup:
    if (items) CFRelease(items);
    return security_key;
}




static BOOL updates_verifyfile(NSString* sig, NSString* emailImmutable) {
    NSData* sigd = [[NSData alloc] initWithBase64EncodedString:sig options:0];
    
    NSMutableString *email = [NSMutableString string];
    for (NSInteger i = [emailImmutable length] - 1; i >= 0; i--)
        [email appendFormat:@"%c", [emailImmutable characterAtIndex:i]];
    
    CFErrorRef error = NULL;
    SecKeyRef security_pubkey = create_public_key();
    SecTransformRef verifier = SecVerifyTransformCreate(security_pubkey, (__bridge CFDataRef)sigd, &error);
    if (error) NSLog(@"crap 1");
    
    CFDataRef emailDataToVerify = (__bridge CFDataRef)[email dataUsingEncoding:NSUTF8StringEncoding];
    SecTransformSetAttribute(verifier, kSecTransformInputAttributeName, emailDataToVerify, &error);
    if (error) NSLog(@"crap 2");
    
    NSNumber* result = (__bridge NSNumber*)SecTransformExecute(verifier, &error);
    return [result boolValue];
}

@implementation HydraLicense

- (void) check {
    NSLog(@"%d", updates_verifyfile(@"MC0CFQCcGckU7tNoN8H4IbyraKpEDedf4AIUV/7au5+vvtuorcvHJCY436BVPeY=", @"vagif.samadoghlu@example.com"));
}

@end
