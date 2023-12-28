// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashCString.m
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

#import "SentryCrashCString.h"

@implementation SentryCrashCString

@synthesize length = _length;
@synthesize bytes = _bytes;

+ (SentryCrashCString *)stringWithString:(NSString *)string
{
    return [[self alloc] initWithString:string];
}

+ (SentryCrashCString *)stringWithCString:(const char *)string
{
    return [[self alloc] initWithCString:string];
}

+ (SentryCrashCString *)stringWithData:(NSData *)data
{
    return [[self alloc] initWithData:data];
}

+ (SentryCrashCString *)stringWithData:(const char *)data length:(NSUInteger)length
{
    return [[self alloc] initWithData:data length:length];
}

- (id)initWithString:(NSString *)string
{
    return [self initWithCString:[string cStringUsingEncoding:NSUTF8StringEncoding]];
}

- (id)initWithCString:(const char *)string
{
    if ((self = [super init])) {
        _bytes = strdup(string);
        if (_bytes != NULL) {
            _length = strlen(_bytes);
        }
    }
    return self;
}

- (id)initWithData:(NSData *)data
{
    return [self initWithData:data.bytes length:data.length];
}

- (id)initWithData:(const char *)data length:(NSUInteger)length
{
    if ((self = [super init])) {
        _length = length;
        char *bytes = malloc((unsigned)_length + 1);
        if (bytes != NULL) {
            memcpy(bytes, data, _length);
            bytes[_length] = 0;
            _bytes = bytes;
        } else {
            _length = 0;
        }
    }
    return self;
}

- (void)dealloc
{
    if (_bytes != NULL) {
        free((void *)_bytes);
    }
}

@end
