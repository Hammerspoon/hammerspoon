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
    NSMutableData *_Nullable data = [NSMutableData dataWithLength:length];
    if (data == nil) {
        [NSException raise:NSInternalInconsistencyException format:@"Failed to allocate random data"];
    }
    int result = SecRandomCopyBytes(kSecRandomDefault, data.length, ((NSMutableData *_Nonnull)data).mutableBytes);
    if (result != errSecSuccess) {
        [NSException raise:NSInternalInconsistencyException format:@"Failed to generate random bytes with OSStatus: %d", result];
    }
    return (NSMutableData *_Nonnull)data;
}

NS_ASSUME_NONNULL_END
