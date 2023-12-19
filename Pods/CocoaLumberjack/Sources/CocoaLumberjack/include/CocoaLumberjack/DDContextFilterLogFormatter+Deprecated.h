// Software License Agreement (BSD License)
//
// Copyright (c) 2010-2023, Deusty, LLC
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

#import <CocoaLumberjack/DDContextFilterLogFormatter.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * This class provides a log formatter that filters log statements from a logging context not on the whitelist.
 * @deprecated Use DDContextAllowlistFilterLogFormatter instead.
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
__attribute__((deprecated("Use DDContextAllowlistFilterLogFormatter instead")))
typedef DDContextAllowlistFilterLogFormatter DDContextWhitelistFilterLogFormatter;

@interface DDContextAllowlistFilterLogFormatter (Deprecated)

/**
 *  Add a context to the whitelist
 *  @deprecated Use -addToAllowlist: instead.
 *
 *  @param loggingContext the context
 */
- (void)addToWhitelist:(NSInteger)loggingContext __attribute__((deprecated("Use -addToAllowlist: instead")));

/**
 *  Remove context from whitelist
 *  @deprecated Use -removeFromAllowlist: instead.
 *
 *  @param loggingContext the context
 */
- (void)removeFromWhitelist:(NSInteger)loggingContext __attribute__((deprecated("Use -removeFromAllowlist: instead")));

/**
 *  Return the whitelist
 *  @deprecated Use allowlist instead.
 */
@property (nonatomic, readonly, copy) NSArray<NSNumber *> *whitelist __attribute__((deprecated("Use allowlist instead")));

/**
 *  Check if a context is on the whitelist
 *  @deprecated Use -isOnAllowlist: instead.
 *
 *  @param loggingContext the context
 */
- (BOOL)isOnWhitelist:(NSInteger)loggingContext __attribute__((deprecated("Use -isOnAllowlist: instead")));

@end


/**
 * This class provides a log formatter that filters log statements from a logging context on the blacklist.
 * @deprecated Use DDContextDenylistFilterLogFormatter instead.
 **/
__attribute__((deprecated("Use DDContextDenylistFilterLogFormatter instead")))
typedef DDContextDenylistFilterLogFormatter DDContextBlacklistFilterLogFormatter;

@interface DDContextDenylistFilterLogFormatter (Deprecated)

/**
 *  Add a context to the blacklist
 *  @deprecated Use -addToDenylist: instead.
 *
 *  @param loggingContext the context
 */
- (void)addToBlacklist:(NSInteger)loggingContext __attribute__((deprecated("Use -addToDenylist: instead")));

/**
 *  Remove context from blacklist
 *  @deprecated Use -removeFromDenylist: instead.
 *
 *  @param loggingContext the context
 */
- (void)removeFromBlacklist:(NSInteger)loggingContext __attribute__((deprecated("Use -removeFromDenylist: instead")));

/**
 *  Return the blacklist
 *  @deprecated Use denylist instead.
 */
@property (readonly, copy) NSArray<NSNumber *> *blacklist __attribute__((deprecated("Use denylist instead")));

/**
 *  Check if a context is on the blacklist
 *  @deprecated Use -isOnDenylist: instead.
 *
 *  @param loggingContext the context
 */
- (BOOL)isOnBlacklist:(NSInteger)loggingContext __attribute__((deprecated("Use -isOnDenylist: instead")));

@end

NS_ASSUME_NONNULL_END
