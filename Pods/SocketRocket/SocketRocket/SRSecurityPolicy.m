//
// Copyright (c) 2016-present, Facebook, Inc.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree. An additional grant
// of patent rights can be found in the PATENTS file in the same directory.
//

#import "SRSecurityPolicy.h"
#import "SRPinningSecurityPolicy.h"

NS_ASSUME_NONNULL_BEGIN

@interface SRSecurityPolicy ()

@property (nonatomic, assign, readonly) BOOL certificateChainValidationEnabled;

@end

@implementation SRSecurityPolicy

+ (instancetype)defaultPolicy
{
    return [self new];
}

+ (instancetype)pinnningPolicyWithCertificates:(NSArray *)pinnedCertificates
{
    [NSException raise:NSInvalidArgumentException
                format:@"Using pinned certificates is neither secure nor supported in SocketRocket, "
                        "and leads to security issues. Please use a proper, trust chain validated certificate."];

    return nil;
}

- (instancetype)initWithCertificateChainValidationEnabled:(BOOL)enabled
{
    self = [super init];
    if (!self) { return self; }

    _certificateChainValidationEnabled = enabled;

    return self;
}

- (instancetype)init
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"

    return [self initWithCertificateChainValidationEnabled:YES];

#pragma clang diagnostic pop
}

- (void)updateSecurityOptionsInStream:(NSStream *)stream
{
    // Enforce TLS 1.2
    [stream setProperty:(__bridge id)CFSTR("kCFStreamSocketSecurityLevelTLSv1_2") forKey:(__bridge id)kCFStreamPropertySocketSecurityLevel];

    // Validate certificate chain for this stream if enabled.
    NSDictionary<NSString *, id> *sslOptions = @{ (__bridge NSString *)kCFStreamSSLValidatesCertificateChain : @(self.certificateChainValidationEnabled) };
    [stream setProperty:sslOptions forKey:(__bridge NSString *)kCFStreamPropertySSLSettings];
}

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust forDomain:(NSString *)domain
{
    // No further evaluation happens in the default policy.
    return YES;
}

@end

NS_ASSUME_NONNULL_END
