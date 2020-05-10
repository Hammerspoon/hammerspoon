//
//  SentryCrashCString.h
//
//  Created by Karl Stenerud on 2013-02-23.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import <Foundation/Foundation.h>

/**
 * A string, stored C style with null termination.
 */
@interface SentryCrashCString : NSObject

/** Length of the string in bytes (not characters!). Length does not include null terminator. */
@property(nonatomic,readonly,assign) NSUInteger length;

/** String contents, including null terminator */
@property(nonatomic,readonly,assign) const char* bytes;

/** Constructor for NSString */
+ (SentryCrashCString*) stringWithString:(NSString*) string;

/** Constructor for null-terminated C string (assumes UTF-8 encoding). */
+ (SentryCrashCString*) stringWithCString:(const char*) string;

/** Constructor for string contained in NSData (assumes UTF-8 encoding). */
+ (SentryCrashCString*) stringWithData:(NSData*) data;

/** Constructor for non-terminated string (assumes UTF-8 encoding). */
+ (SentryCrashCString*) stringWithData:(const char*) data length:(NSUInteger) length;

- (id) initWithString:(NSString*) string;
- (id) initWithCString:(const char*) string;
- (id) initWithData:(NSData*) data;
- (id) initWithData:(const char*) data length:(NSUInteger) length;

@end
