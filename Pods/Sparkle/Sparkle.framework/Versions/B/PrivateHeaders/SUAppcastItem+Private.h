//
//  SUAppcastItem+Private.h
//  Sparkle
//
//  Created by Mayur Pawashe on 4/30/21.
//  Copyright © 2021 Sparkle Project. All rights reserved.
//

#ifndef SUAppcastItem_Private_h
#define SUAppcastItem_Private_h

#if __has_feature(modules)
#if __has_warning("-Watimport-in-framework-header")
#pragma clang diagnostic ignored "-Watimport-in-framework-header"
#endif
@import Foundation;
#else
#import <Foundation/Foundation.h>
#endif

NS_ASSUME_NONNULL_BEGIN

// Available in SPUAppcastItemStateResolver.h (a private exposed header)
@class SPUAppcastItemStateResolver;

@interface SUAppcastItem (Private) <NSSecureCoding>

/**
 Initializes with data from a dictionary provided by the RSS class and state resolver

 This initializer method is intended to be marked "private" and discouraged from public usage.
 This method is available however. Talk to us to describe your use case and if you need to construct appcast items yourself.
 */
- (nullable instancetype)initWithDictionary:(NSDictionary *)dict relativeToURL:(NSURL * _Nullable)appcastURL stateResolver:(SPUAppcastItemStateResolver *)stateResolver failureReason:(NSString * _Nullable __autoreleasing *_Nullable)error;

/**
 The DSA and EdDSA signatures along with their statuses.
 */
@property (readonly, nullable) SUSignatures *signatures;

@end

NS_ASSUME_NONNULL_END

#endif /* SUAppcastItem_Private_h */
