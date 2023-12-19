//
// Copyright (c) 2016-present, Facebook, Inc.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree. An additional grant
// of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

#import <SocketRocket/SRSecurityPolicy.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * NOTE: While publicly, SocketRocket does not support configuring the security policy with pinned certificates,
 * it is still possible to manually construct a security policy of this class. If you do this, note that you may
 * be open to MitM attacks, and we will not support any issues you may have. Dive at your own risk.
 */
@interface SRPinningSecurityPolicy : SRSecurityPolicy

- (instancetype)initWithCertificates:(NSArray *)pinnedCertificates;

@end

NS_ASSUME_NONNULL_END
