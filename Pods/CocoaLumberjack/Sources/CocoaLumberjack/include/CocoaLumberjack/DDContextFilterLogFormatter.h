// Software License Agreement (BSD License)
//
// Copyright (c) 2010-2021, Deusty, LLC
// All rights reserved.
//
// Redistribution and use of this software in source and binary forms,
// with or without modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
//
// * Neither the name of Deusty nor the names of its contributors may be used
//   to endorse or promote products derived from this software without specific
//   prior written permission of Deusty, LLC.

#import <Foundation/Foundation.h>

// Disable legacy macros
#ifndef DD_LEGACY_MACROS
    #define DD_LEGACY_MACROS 0
#endif

#import <CocoaLumberjack/DDLog.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * This class provides a log formatter that filters log statements from a logging context not on the allowlist.
 *
 * A log formatter can be added to any logger to format and/or filter its output.
 * You can learn more about log formatters here:
 * Documentation/CustomFormatters.md
 *
 * You can learn more about logging context's here:
 * Documentation/CustomContext.md
 *
 * But here's a quick overview / refresher:
 *
 * Every log statement has a logging context.
 * These come from the underlying logging macros defined in DDLog.h.
 * The default logging context is zero.
 * You can define multiple logging context's for use in your application.
 * For example, logically separate parts of your app each have a different logging context.
 * Also 3rd party frameworks that make use of Lumberjack generally use their own dedicated logging context.
 **/
@interface DDContextAllowlistFilterLogFormatter : NSObject <DDLogFormatter>

/**
 *  Designated default initializer
 */
- (instancetype)init NS_DESIGNATED_INITIALIZER;

/**
 *  Add a context to the allowlist
 *
 *  @param loggingContext the context
 */
- (void)addToAllowlist:(NSInteger)loggingContext;

/**
 *  Remove context from allowlist
 *
 *  @param loggingContext the context
 */
- (void)removeFromAllowlist:(NSInteger)loggingContext;

/**
 *  Return the allowlist
 */
@property (nonatomic, readonly, copy) NSArray<NSNumber *> *allowlist;

/**
 *  Check if a context is on the allowlist
 *
 *  @param loggingContext the context
 */
- (BOOL)isOnAllowlist:(NSInteger)loggingContext;

@end


/**
 * This class provides a log formatter that filters log statements from a logging context on the denylist.
 **/
@interface DDContextDenylistFilterLogFormatter : NSObject <DDLogFormatter>

- (instancetype)init NS_DESIGNATED_INITIALIZER;

/**
 *  Add a context to the denylist
 *
 *  @param loggingContext the context
 */
- (void)addToDenylist:(NSInteger)loggingContext;

/**
 *  Remove context from denylist
 *
 *  @param loggingContext the context
 */
- (void)removeFromDenylist:(NSInteger)loggingContext;

/**
 *  Return the denylist
 */
@property (readonly, copy) NSArray<NSNumber *> *denylist;

/**
 *  Check if a context is on the denylist
 *
 *  @param loggingContext the context
 */
- (BOOL)isOnDenylist:(NSInteger)loggingContext;

@end

NS_ASSUME_NONNULL_END
