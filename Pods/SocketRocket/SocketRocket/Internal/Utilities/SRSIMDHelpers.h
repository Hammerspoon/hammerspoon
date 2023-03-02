//
// Copyright (c) 2016-present, Facebook, Inc.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree. An additional grant
// of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

/**
 Unmask bytes using XOR via SIMD.

 @param bytes    The bytes to unmask.
 @param length   The number of bytes to unmask.
 @param maskKey The mask to XOR with MUST be of length sizeof(uint32_t).
 */
void SRMaskBytesSIMD(uint8_t *bytes, size_t length, uint8_t *maskKey);
