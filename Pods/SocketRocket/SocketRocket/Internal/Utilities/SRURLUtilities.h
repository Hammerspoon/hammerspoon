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

// The origin isn't really applicable for a native application.
// So instead, just map ws -> http and wss -> https.
extern NSString *SRURLOrigin(NSURL *url);

extern BOOL SRURLRequiresSSL(NSURL *url);

// Extracts `user` and `password` from url (if available) into `Basic base64(user:password)`.
extern NSString *_Nullable SRBasicAuthorizationHeaderFromURL(NSURL *url);

// Returns a valid value for `NSStreamNetworkServiceType` or `nil`.
extern NSString *_Nullable SRStreamNetworkServiceTypeFromURLRequest(NSURLRequest *request);

NS_ASSUME_NONNULL_END
