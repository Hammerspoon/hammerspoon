//
// Copyright (c) 2016-present, Facebook, Inc.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree. An additional grant
// of patent rights can be found in the PATENTS file in the same directory.
//

#import "SRRandom.h"

#import <Security/SecRandom.h>

NS_ASSUME_NONNULL_BEGIN

NSData *SRRandomData(NSUInteger length)
{
    NSMutableData *data = [NSMutableData dataWithLength:length];
    int result = SecRandomCopyBytes(kSecRandomDefault, data.length, data.mutableBytes);
    if (result != 0) {
        [NSException raise:NSInternalInconsistencyException format:@"Failed to generate random bytes with OSStatus: %d", result];
    }
    return data;
}

NS_ASSUME_NONNULL_END
