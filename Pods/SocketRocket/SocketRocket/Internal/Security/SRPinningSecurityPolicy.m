//
// Copyright (c) 2016-present, Facebook, Inc.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree. An additional grant
// of patent rights can be found in the PATENTS file in the same directory.
//

#import "SRPinningSecurityPolicy.h"

#import <Foundation/Foundation.h>

#import "SRLog.h"

NS_ASSUME_NONNULL_BEGIN

@interface SRPinningSecurityPolicy ()

@property (nonatomic, copy, readonly) NSArray *pinnedCertificates;

@end

@implementation SRPinningSecurityPolicy

- (instancetype)initWithCertificates:(NSArray *)pinnedCertificates
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"

    // Do not validate certificate chain since we're pinning to specific certificates.
    self = [super initWithCertificateChainValidationEnabled:NO];

#pragma clang diagnostic pop

    if (!self) { return self; }

    if (pinnedCertificates.count == 0) {
        @throw [NSException exceptionWithName:@"Creating security policy failed."
                                       reason:@"Must specify at least one certificate when creating a pinning policy."
                                     userInfo:nil];
    }
    _pinnedCertificates = [pinnedCertificates copy];

    return self;
}

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust forDomain:(NSString *)domain
{
    SRDebugLog(@"Pinned cert count: %d", self.pinnedCertificates.count);
    NSUInteger requiredCertCount = self.pinnedCertificates.count;

    NSUInteger validatedCertCount = 0;
    CFIndex serverCertCount = SecTrustGetCertificateCount(serverTrust);
    for (CFIndex i = 0; i < serverCertCount; i++) {
        SecCertificateRef cert = SecTrustGetCertificateAtIndex(serverTrust, i);
        NSData *data = CFBridgingRelease(SecCertificateCopyData(cert));
        for (id ref in self.pinnedCertificates) {
            SecCertificateRef trustedCert = (__bridge SecCertificateRef)ref;
            // TODO: (nlutsenko) Add caching, so we don't copy the data for every pinned cert all the time.
            NSData *trustedCertData = CFBridgingRelease(SecCertificateCopyData(trustedCert));
            if ([trustedCertData isEqualToData:data]) {
                validatedCertCount++;
                break;
            }
        }
    }
    return (requiredCertCount == validatedCertCount);
}

@end

NS_ASSUME_NONNULL_END
