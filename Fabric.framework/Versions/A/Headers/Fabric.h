//
//  Fabric.h
//
//  Copyright (c) 2015 Twitter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FABAttributes.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Fabric Base. Coordinates configuration and starts all provided kits.
 */
@interface Fabric : NSObject

/**
 * Initialize Fabric and all provided kits. Call this method within your App Delegate's `application:didFinishLaunchingWithOptions:` and provide the kits you wish to use.
 *
 * For example, in Objective-C:
 *
 *      `[Fabric with:@[[Crashlytics class], [Twitter class], [Digits class], [MoPub class]]];`
 *
 * Swift:
 *
 *      `Fabric.with([Crashlytics.self(), Twitter.self(), Digits.self(), MoPub.self()])`
 *
 * Only the first call to this method is honored. Subsequent calls are no-ops.
 *
 * @param kitClasses An array of kit Class objects
 *
 * @return Returns the shared Fabric instance. In most cases this can be ignored.
 */
+ (instancetype)with:(NSArray *)kitClasses;

/**
 *  Returns the Fabric singleton object.
 */
+ (instancetype)sharedSDK;

/**
 *  This BOOL enables or disables debug logging, such as kit version information. The default value is NO.
 */
@property (nonatomic, assign) BOOL debug;

/**
 *  Unavailable. Use `+sharedSDK` to retrieve the shared Fabric instance.
 */
- (id)init FAB_UNAVAILABLE("Use +sharedSDK to retrieve the shared Fabric instance.");

@end

NS_ASSUME_NONNULL_END

