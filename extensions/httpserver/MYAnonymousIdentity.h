//
//  MYAnonymousIdentity.h
//  MYUtilities
//
//  Created by Jens Alfke on 12/5/14.
//

#import <Foundation/Foundation.h>
#import <Security/SecBase.h>


/** Generates a valid but anonymous X.509 certificate (with 2048-bit RSA key) that's useable for
    an SSL server. It's anonymous because it's self-signed and the "subject" and "issuer" strings
    are just fixed placeholders.
    The cert and key are stored in the keychain under the given label; if they already exist and
    haven't expired, the existing identity will be returned instead of creating a new one.
    @param label  A string identifying the purpose of this identity.
    @param expirationInterval  The amount of time the certificate should remain valid.
            Typically a year.
    @return  An autoreleased identity reference that can be used when configuring a socket for SSL
            using the CFStream or SecureTransport APIs. */
SecIdentityRef MYGetOrCreateAnonymousIdentity(NSString* label,
                                              NSTimeInterval expirationInterval,
                                              NSError** outError);

/** Removes an identity created by MYGetOrCreateAnonymousIdentity from the keychain.
    @param label  Label given to the identity when it was created.
    @return  YES if an identity was removed, NO if not. */
BOOL MYDeleteAnonymousIdentity(NSString* label);

/** Convenience function to get the SHA-1 digest of a certificate.
    This is a handy way to uniquely identify the certificate. For example, as the owner of an
    identity you can send this digest to someone else over an existing secure channel, and they can
    then make an SSL connection to you and verify your identity by comparing cert digests. */
NSData* MYGetCertificateDigest(SecCertificateRef cert);

#define kMYAnonymousIdentityDefaultExpirationInterval (60*60*24*365.0)
