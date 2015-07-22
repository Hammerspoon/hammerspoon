// Software License Agreement (BSD License)
//
// Copyright (c) 2010-2015, Deusty, LLC
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

#import "DDLog.h"

/**
 * This formatter can be used to chain different formatters together.
 * The log message will processed in the order of the formatters added.
 **/

@interface DDMultiFormatter : NSObject <DDLogFormatter>

/**
 *  Array of chained formatters
 */
@property (readonly) NSArray *formatters;

- (void)addFormatter:(id<DDLogFormatter>)formatter;
- (void)removeFormatter:(id<DDLogFormatter>)formatter;
- (void)removeAllFormatters;
- (BOOL)isFormattingWithFormatter:(id<DDLogFormatter>)formatter;

@end
