//
// Copyright 2012 Square Inc.
// Portions Copyright (c) 2016-present, Facebook, Inc.
//
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree. An additional grant
// of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSRunLoop (SRWebSocket)

/**
 Default run loop that will be used to schedule all instances of `SRWebSocket`.

 @return An instance of `NSRunLoop`.
 */
+ (NSRunLoop *)SR_networkRunLoop;

@end

NS_ASSUME_NONNULL_END
