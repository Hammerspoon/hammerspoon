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

#import "DDASLLogger.h"

@protocol DDLogger;

/**
 *  This class provides the ability to capture the ASL (Apple System Logs)
 */
@interface DDASLLogCapture : NSObject

+ (void)start;
+ (void)stop;

// Default log level: DDLogLevelVerbose (i.e. capture all ASL messages).
+ (DDLogLevel)captureLevel;
+ (void)setCaptureLevel:(DDLogLevel)level;

@end
