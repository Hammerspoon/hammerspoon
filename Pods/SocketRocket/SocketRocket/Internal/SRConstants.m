//
// Copyright (c) 2016-present, Facebook, Inc.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree. An additional grant
// of patent rights can be found in the PATENTS file in the same directory.
//

#import "SRConstants.h"

size_t SRDefaultBufferSize(void) {
    static size_t size;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        size = getpagesize();
    });
    return size;
}
