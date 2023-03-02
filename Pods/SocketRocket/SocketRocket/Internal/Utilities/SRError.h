//
// Copyright (c) 2016-present, Facebook, Inc.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree. An additional grant
// of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSError *SRErrorWithDomainCodeDescription(NSString *domain, NSInteger code, NSString *description);
extern NSError *SRErrorWithCodeDescription(NSInteger code, NSString *description);
extern NSError *SRErrorWithCodeDescriptionUnderlyingError(NSInteger code, NSString *description, NSError *underlyingError);

extern NSError *SRHTTPErrorWithCodeDescription(NSInteger httpCode, NSInteger errorCode, NSString *description);

NS_ASSUME_NONNULL_END
