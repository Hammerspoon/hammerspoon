//
// Copyright (c) 2016-present, Facebook, Inc.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree. An additional grant
// of patent rights can be found in the PATENTS file in the same directory.
//

#import "SRHash.h"

#import <CommonCrypto/CommonDigest.h>

NS_ASSUME_NONNULL_BEGIN

NSData *SRSHA1HashFromString(NSString *string)
{
    const char *utf8String = string.UTF8String;
    if (!utf8String) {
        return [NSData data];
    }
    size_t length = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    return SRSHA1HashFromBytes(utf8String, length);
}

NSData *SRSHA1HashFromBytes(const char *bytes, size_t length)
{
    uint8_t outputLength = CC_SHA1_DIGEST_LENGTH;
    unsigned char output[outputLength];
    CC_SHA1(bytes, (CC_LONG)length, output);

    return [NSData dataWithBytes:output length:outputLength];
}

NSString *SRBase64EncodedStringFromData(NSData *data)
{
    if ([data respondsToSelector:@selector(base64EncodedStringWithOptions:)]) {
        return [data base64EncodedStringWithOptions:0];
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [data base64Encoding];
#pragma clang diagnostic pop
}

NS_ASSUME_NONNULL_END
