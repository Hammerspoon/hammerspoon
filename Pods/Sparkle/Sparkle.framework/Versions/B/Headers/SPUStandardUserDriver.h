//
//  SPUStandardUserDriver.h
//  Sparkle
//
//  Created by Mayur Pawashe on 2/14/16.
//  Copyright © 2016 Sparkle Project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Sparkle/SPUUserDriver.h>
#import <Sparkle/SUExport.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SPUStandardUserDriverDelegate;

/**
 Sparkle's standard built-in user driver for updater interactions
 */
SU_EXPORT @interface SPUStandardUserDriver : NSObject <SPUUserDriver>

/**
 Initializes a Sparkle's standard user driver for user update interactions
 
 @param hostBundle The target bundle of the host that is being updated.
 @param delegate The optional delegate to this user driver.
 */
- (instancetype)initWithHostBundle:(NSBundle *)hostBundle delegate:(nullable id<SPUStandardUserDriverDelegate>)delegate;

/**
 Use initWithHostBundle:delegate: instead.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
