//
//  MYAnonymousIdentity.m
//  MYUtilities
//
//  Created by Jens Alfke on 12/5/14.
//

#import "MYAnonymousIdentity.h"
#import "HammerspoonCertTemplate.h"
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>


// Key size of kCertTemplate:
#define kKeySizeInBits     2048

// These are offsets into kCertTemplate where values need to be substituted:
#define kSerialLength         1
#define kDateLength          13
#define kPublicKeyLength    270u
#define kCSROffset            0
#define kSignatureLength    256u


static BOOL checkErr(OSStatus err, NSError** outError);
static NSData* generateAnonymousCert(SecKeyRef publicKey, SecKeyRef privateKey,
                                     NSTimeInterval expirationInterval,
                                     NSError** outError);
static BOOL checkCertValid(SecCertificateRef cert, NSTimeInterval expirationInterval);
static BOOL generateRSAKeyPair(int sizeInBits,
                               BOOL permanent,
                               NSString* label,
                               SecKeyRef *publicKey,
                               SecKeyRef *privateKey,
                               NSError** outError);
static NSData* getPublicKeyData(SecKeyRef publicKey);
static NSData* signData(SecKeyRef privateKey, NSData* inputData);
static SecCertificateRef addCertToKeychain(NSData* certData, NSString* label,
                                           NSError** outError);
static SecIdentityRef findIdentity(NSString* label, NSTimeInterval expirationInterval);

#if TARGET_OS_IPHONE
static void removePublicKey(SecKeyRef publicKey);
#endif


SecIdentityRef MYGetOrCreateAnonymousIdentity(NSString* label,
                                              NSTimeInterval expirationInterval,
                                              NSError** outError)
{
    NSCParameterAssert(label);
    SecIdentityRef ident = findIdentity(label, expirationInterval);
    if (!ident) {
        NSLog(@"Generating new anonymous self-signed SSL identity labeled \"%@\"...", label);
        SecKeyRef publicKey, privateKey;
        if (!generateRSAKeyPair(kKeySizeInBits, YES, label, &publicKey, &privateKey, outError))
            return NULL;
        NSData* certData = generateAnonymousCert(publicKey,privateKey, expirationInterval,outError);
        if (!certData)
            return NULL;
        SecCertificateRef certRef = addCertToKeychain(certData, label, outError);
        if (!certRef)
            return NULL;
#if TARGET_OS_IPHONE
        removePublicKey(publicKey); // workaround for Radar 18205627
        ident = findIdentity(label, expirationInterval);
        if (!ident)
            checkErr(errSecItemNotFound, outError);
#else
        if (checkErr(SecIdentityCreateWithCertificate(NULL, certRef, &ident), outError))
            CFAutorelease(ident);
#endif
        if (!ident)
            NSLog(@"MYAnonymousIdentity: Can't find identity we just created");
    }
    return ident;
}


static BOOL checkErr(OSStatus err, NSError** outError) {
    if (err == noErr)
        return YES;
    NSDictionary* info = nil;
#if !TARGET_OS_IPHONE
    NSString* message = CFBridgingRelease(SecCopyErrorMessageString(err, NULL));
    if (message)
        info = @{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@ (%d)", message, (int)err]};
#endif
    if (outError)
        *outError = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: info];
    return NO;
}


// Generates an RSA key-pair, optionally adding it to the keychain.
static BOOL generateRSAKeyPair(int sizeInBits,
                               BOOL permanent,
                               NSString* label,
                               SecKeyRef *publicKey,
                               SecKeyRef *privateKey,
                               NSError** outError)
{
#if TARGET_OS_IPHONE
    NSDictionary *keyAttrs = @{(__bridge id)kSecAttrIsPermanent: @(permanent),
                               (__bridge id)kSecAttrLabel: label};
#endif
    NSDictionary *pairAttrs = @{(__bridge id)kSecAttrKeyType:       (__bridge id)kSecAttrKeyTypeRSA,
                                (__bridge id)kSecAttrKeySizeInBits: @(sizeInBits),
                                (__bridge id)kSecAttrLabel:         label,
#if TARGET_OS_IPHONE
                                (__bridge id)kSecPublicKeyAttrs:    keyAttrs,
                                (__bridge id)kSecPrivateKeyAttrs:   keyAttrs
#else
                                (__bridge id)kSecAttrIsPermanent:   @(permanent)
#endif
                                };
    if (!checkErr(SecKeyGeneratePair((__bridge CFDictionaryRef)pairAttrs, publicKey, privateKey),
                  outError))
        return NO;
    CFAutorelease(*publicKey);
    CFAutorelease(*privateKey);
    return YES;
}


// Generates a self-signed certificate, returning the cert data.
static NSData* generateAnonymousCert(SecKeyRef publicKey, SecKeyRef privateKey,
                                     NSTimeInterval expirationInterval,
                                     NSError** outError __unused)
{
    // Read the original template certificate file:
    NSMutableData* data = [NSMutableData dataWithBytes: kCertTemplate length: sizeof(kCertTemplate)];
    uint8_t* buf = data.mutableBytes;

    // Write the serial number:
    if (SecRandomCopyBytes(kSecRandomDefault, kSerialLength, &buf[kSerialOffset]) != 0) {
        NSLog(@"SecRandomCopyBytes() failed");
        return nil;
    }
    buf[kSerialOffset] &= 0x7F; // non-negative

    // Write the issue and expiration dates:
    NSDateFormatter *x509DateFormatter = [[NSDateFormatter alloc] init];
    x509DateFormatter.dateFormat = @"yyMMddHHmmss'Z'";
    x509DateFormatter.timeZone = [NSTimeZone timeZoneWithName: @"GMT"];
    NSDate* date = [NSDate date];
    const char* dateStr = [[x509DateFormatter stringFromDate: date] UTF8String];
    memcpy(&buf[kIssueDateOffset], dateStr, kDateLength);
    date = [date dateByAddingTimeInterval: expirationInterval];
    dateStr = [[x509DateFormatter stringFromDate: date] UTF8String];
    memcpy(&buf[kExpDateOffset], dateStr, kDateLength);

    // Copy the public key:
    NSData* keyData = getPublicKeyData(publicKey);
    if (keyData.length != kPublicKeyLength) {
        NSLog(@"ERROR: keyData.length (%lu) != kPublicKeyLength (%i)", keyData.length, kPublicKeyLength);
        return nil;
    }
    memcpy(&buf[kPublicKeyOffset], keyData.bytes, kPublicKeyLength);

    // Sign the cert:
    NSData* csr = [data subdataWithRange: NSMakeRange(kCSROffset, kCSRLength)];
    NSData* sig = signData(privateKey, csr);
    if (sig.length != kSignatureLength) {
        NSLog(@"ERROR: sig.length (%lu) != kSignatureLength (%i)", sig.length, kSignatureLength);
        return nil;
    }
    [data appendData: sig];

    return data;
}


// Returns the data of an RSA public key, in the format used in an X.509 certificate.
static NSData* getPublicKeyData(SecKeyRef publicKey) {
#if TARGET_OS_IPHONE
    NSDictionary *info = @{(__bridge id)kSecValueRef:   (__bridge id)publicKey,
                           (__bridge id)kSecReturnData: @YES};
    CFTypeRef data;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)info, &data) != noErr) {
        Log(@"SecItemCopyMatching failed; input = %@", info);
        return nil;
    }
    Assert(data!=NULL);
    return CFBridgingRelease(data);
#else
    CFDataRef data = NULL;
    if (SecItemExport(publicKey, kSecFormatBSAFE, 0, NULL, &data) != noErr)
        return nil;
    return (NSData*)CFBridgingRelease(data);
#endif
}


#if TARGET_OS_IPHONE
// workaround for Radar 18205627: When iOS reads an identity from the keychain, it may accidentally
// get the public key instead of the private key. The workaround is to remove the public key so
// that only the private one is obtainable. --jpa 6/2015
static void removePublicKey(SecKeyRef publicKey) {
    NSDictionary* query = @{(__bridge id)kSecValueRef: (__bridge id)publicKey};
    OSStatus err = SecItemDelete((__bridge CFDictionaryRef)query);
    if (err)
        NSLog(@"Couldn't delete public key: err %d", (int)err);
}
#endif


// Signs a data blob using a private key. Padding is PKCS1 with SHA-1 digest.
static NSData* signData(SecKeyRef privateKey, NSData* inputData) {
#if TARGET_OS_IPHONE
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(inputData.bytes, (CC_LONG)inputData.length, digest);

    size_t sigLen = 1024;
    uint8_t sigBuf[sigLen];
    OSStatus err = SecKeyRawSign(privateKey, kSecPaddingPKCS1SHA1,
                                 digest, sizeof(digest),
                                 sigBuf, &sigLen);
    if(err) {
        NSLog(@"SecKeyRawSign failed: %ld", (long)err);
        return nil;
    }
    return [NSData dataWithBytes: sigBuf length: sigLen];

#else
    SecTransformRef transform = SecSignTransformCreate(privateKey, NULL);
    if (!transform)
        return nil;
    NSData* resultData = nil;
    if (SecTransformSetAttribute(transform, kSecDigestTypeAttribute, kSecDigestSHA1, NULL)
        && SecTransformSetAttribute(transform, kSecTransformInputAttributeName,
                                    (__bridge CFDataRef)inputData, NULL)) {
            resultData = CFBridgingRelease(SecTransformExecute(transform, NULL));
        }
    CFRelease(transform);
    return resultData;
#endif
}


// Adds a certificate to the keychain, tagged with a label for future lookup.
static SecCertificateRef addCertToKeychain(NSData* certData, NSString* label,
                                           NSError** outError) {
    SecCertificateRef certRef = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certData);
    if (!certRef) {
        checkErr(errSecIO, outError);
        return NULL;
    }
    CFAutorelease(certRef);
    NSDictionary* attrs = @{(__bridge id)kSecClass:     (__bridge id)kSecClassCertificate,
                            (__bridge id)kSecValueRef:  (__bridge id)certRef,
#if TARGET_OS_IPHONE
                            (__bridge id)kSecAttrLabel: label
#endif
                            };
    CFTypeRef result;
    OSStatus err = SecItemAdd((__bridge CFDictionaryRef)attrs, &result);
    if (err != noErr) {
        NSLog(@"ERROR: SecItemAdd() returned %i", err);
    }

#if !TARGET_OS_IPHONE
    // kSecAttrLabel is not settable on Mac OS (it's automatically generated from the principal
    // name.) Instead we use the "preference" mapping mechanism, which only exists on Mac OS.
    if (!err)
        err = SecCertificateSetPreferred(certRef, (__bridge CFStringRef)label, NULL);
        if (!err) {
            // Check if this is an identity cert, i.e. we have the corresponding private key.
            // If so, we'll also set the preference for the resulting SecIdentityRef.
            SecIdentityRef identRef;
            if (SecIdentityCreateWithCertificate(NULL,  certRef,  &identRef) == noErr) {
                err = SecIdentitySetPreferred(identRef, (__bridge CFStringRef)label, NULL);
                CFRelease(identRef);
            }
        }
#endif
    checkErr(err, outError);
    return certRef;
}


// Looks up an identity (cert + private key) by the cert's label.
static SecIdentityRef findIdentity(NSString* label, NSTimeInterval expirationInterval) {
    SecIdentityRef identity;
#if TARGET_OS_IPHONE
    NSDictionary* query = @{(__bridge id)kSecClass:     (__bridge id)kSecClassIdentity,
                            (__bridge id)kSecAttrLabel: label,
                            (__bridge id)kSecReturnRef: @YES};
    CFTypeRef ref = NULL;
    OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)query, &ref);
    if (err) {
        AssertEq(err, errSecItemNotFound); // other err indicates query dict is malformed
        return NULL;
    }
    identity = (SecIdentityRef)ref;
#else
    identity = SecIdentityCopyPreferred((__bridge CFStringRef)label, NULL, NULL);
#endif

    if (identity) {
        // Check that the cert hasn't expired yet:
        CFAutorelease(identity);
        SecCertificateRef cert;
        if (SecIdentityCopyCertificate(identity, &cert) == noErr) {
            if (!checkCertValid(cert, expirationInterval)) {
                NSLog(@"SSL identity labeled \"%@\" has expired", label);
                identity = NULL;
                MYDeleteAnonymousIdentity(label);
            }
            CFRelease(cert);
        } else {
            identity = NULL;
        }
    }
    return identity;
}


NSData* MYGetCertificateDigest(SecCertificateRef cert) {
    CFDataRef data = SecCertificateCopyData(cert);
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(CFDataGetBytePtr(data), (CC_LONG)CFDataGetLength(data), digest);
    CFRelease(data);
    return [NSData dataWithBytes: digest length: sizeof(digest)];
}


#if TARGET_OS_IPHONE
static NSDictionary* getItemAttributes(CFTypeRef cert) {
    NSDictionary* query = @{(__bridge id)kSecValueRef: (__bridge id)cert,
                            (__bridge id)kSecReturnAttributes: @YES};
    CFDictionaryRef attrs = NULL;
    OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef*)&attrs);
    if (err) {
        AssertEq(err, errSecItemNotFound);
        return NULL;
    }
    Assert(attrs);
    return CFBridgingRelease(attrs);
}
#endif


#if !TARGET_OS_IPHONE
static double relativeTimeFromOID(NSDictionary* values, CFTypeRef oid) {
    NSNumber* dateNum = values[(__bridge id)oid][@"value"];
    if (!dateNum)
        return 0.0;
    return dateNum.doubleValue - CFAbsoluteTimeGetCurrent();
}
#endif


// Returns YES if the cert has not yet expired.
static BOOL checkCertValid(SecCertificateRef cert, NSTimeInterval expirationInterval __unused) {
#if TARGET_OS_IPHONE
    NSDictionary* attrs = getItemAttributes(cert);
    // The fucked-up iOS Keychain API doesn't expose the cert expiration date, only the date the
    // item was added to the keychain. So derive it based on the current expiration interval:
    NSDate* creationDate = attrs[(__bridge id)kSecAttrCreationDate];
    return creationDate && -[creationDate timeIntervalSinceNow] < expirationInterval;
#else
    CFArrayRef oids = (__bridge CFArrayRef)@[(__bridge id)kSecOIDX509V1ValidityNotAfter,
                                             (__bridge id)kSecOIDX509V1ValidityNotBefore];
    NSDictionary* values = CFBridgingRelease(SecCertificateCopyValues(cert, oids, NULL));
    return relativeTimeFromOID(values, kSecOIDX509V1ValidityNotAfter) >= 0.0
        && relativeTimeFromOID(values, kSecOIDX509V1ValidityNotBefore) <= 0.0;
#endif
}


BOOL MYDeleteAnonymousIdentity(NSString* label) {
    NSDictionary* attrs = @{(__bridge id)kSecClass:     (__bridge id)kSecClassIdentity,
                            (__bridge id)kSecAttrLabel: label};
    OSStatus err = SecItemDelete((__bridge CFDictionaryRef)attrs);
    if (err != noErr && err != errSecItemNotFound)
        NSLog(@"Unexpected error %d deleting identity from keychain", (int)err);
    return (err == noErr);
}


/*
 Copyright (c) 2014-15, Jens Alfke <jens@mooseyard.com>. All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted
 provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions
 and the following disclaimer in the documentation and/or other materials provided with the
 distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRI-
 BUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
 THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
