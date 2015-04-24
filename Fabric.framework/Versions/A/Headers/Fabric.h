//
//  Fabric.h
//
//  Copyright (c) 2014 Twitter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FABAttributes.h"

FAB_START_NONNULL

/**
 *  Fabric Base. Coordinates configuration and starts all provided kits.
 */
@interface Fabric : NSObject

/**
 *  Initialize Fabric and all provided kits. Call this method within your App Delegate's
 *  `application:didFinishLaunchingWithOptions:` and provide the kits you wish to use.
 *
 *  For example, in Objective-C:
 *
 *      `[Fabric with:@[TwitterKit, CrashlyticsKit, MoPubKit]];`
 *
 *  Swift:
 *
 *      `Fabric.with([Twitter(), Crashlytics(), MoPub()])`
 *  
 *  Only the first call to this method is honored. Subsequent calls are no-ops.
 *
 *  @param kits An array of kit instances. Kits may provide a macro such as CrashlyticsKit which can be passed in as array elements in objective-c.
 *
 *  @return Returns the shared Fabric instance. In most cases this can be ignored.
 */
+ (instancetype)with:(NSArray *)kits;

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

/**
 *  Returns Fabrics's instance of the specified kit.
 *
 *  @param klass The class of the kit.
 *
 *  @return The kit instance of class klass which was provided to with: or nil.
 */
- (id FAB_NULLABLE)kitForClass:(Class)klass;

/**
 *  Returns a dictionary containing the kit configuration info for the provided kit.
 *  The configuration information is parsed from the application's Info.plist. This
 *  method is primarily intended to be used by kits to retrieve their configuration.
 *
 *  @param kitInstance An instance of the kit whose configuration should be returned.
 *
 *  @return A dictionary containing kit specific configuration information or nil if none exists.
 */
- (NSDictionary * FAB_NULLABLE)configurationDictionaryForKit:(id)kitInstance;

@end

FAB_END_NONNULL

