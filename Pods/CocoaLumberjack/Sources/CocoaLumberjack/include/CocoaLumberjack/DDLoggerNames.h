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

NS_ASSUME_NONNULL_BEGIN

typedef NSString *DDLoggerName NS_EXTENSIBLE_STRING_ENUM;

FOUNDATION_EXPORT DDLoggerName const DDLoggerNameOS NS_SWIFT_NAME(DDLoggerName.os);     // DDOSLogger
FOUNDATION_EXPORT DDLoggerName const DDLoggerNameFile NS_SWIFT_NAME(DDLoggerName.file); // DDFileLogger

FOUNDATION_EXPORT DDLoggerName const DDLoggerNameTTY NS_SWIFT_NAME(DDLoggerName.tty);   // DDTTYLogger

API_DEPRECATED("Use DDOSLogger instead", macosx(10.4, 10.12), ios(2.0, 10.0), watchos(2.0, 3.0), tvos(9.0, 10.0))
FOUNDATION_EXPORT DDLoggerName const DDLoggerNameASL NS_SWIFT_NAME(DDLoggerName.asl);   // DDASLLogger

NS_ASSUME_NONNULL_END
