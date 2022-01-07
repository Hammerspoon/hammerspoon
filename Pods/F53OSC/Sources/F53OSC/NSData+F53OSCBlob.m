//
//  NSData+F53OSCBlob.m
//
//  Created by Siobhán Dougall on 1/17/11.
//
//  Copyright (c) 2011-2020 Figure 53 LLC, https://figure53.com
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import "NSData+F53OSCBlob.h"


NS_ASSUME_NONNULL_BEGIN

@implementation NSData (F53OSCBlobAdditions)

- (NSData *) oscBlobData
{
    UInt32 dataSize = (UInt32)[self length];
    dataSize = OSSwapHostToBigInt32( dataSize );
    NSMutableData *newData = [NSMutableData dataWithBytes:&dataSize length:sizeof(UInt32)];
    
    [newData appendData:self];
 
    // In OSC everything is in multiples of 4 bytes. We must add null bytes to pad out to 4.
    char zero = 0;
    for ( int i = ([self length] - 1) % 4; i < 3; i++ )
        [newData appendBytes:&zero length:1];
    
    return [newData copy];
}

///
///  An OSC blob is an int32 size count followed by a sequence of 8-bit bytes,
///  followed by 0-3 additional null characters to make the total number of bits a multiple of 32.
///
+ (nullable NSData *) dataWithOSCBlobBytes:(const char *)buf maxLength:(NSUInteger)maxLength bytesRead:(out NSUInteger *)outBytesRead
{
    if ( buf == NULL || maxLength == 0 )
    {
        if ( outBytesRead != NULL )
            *outBytesRead = 0;
        return nil;
    }
    
    UInt32 dataSize = 0;
    
    dataSize = *((UInt32 *)buf);
    dataSize = OSSwapBigToHostInt32( dataSize );
    
    if ( dataSize + 4 > maxLength )
    {
        if ( outBytesRead != NULL )
            *outBytesRead = 0;
        return nil;
    }
    
    if ( outBytesRead != NULL )
        *outBytesRead = dataSize;
    
    buf += 4;
    NSData *result = [NSData dataWithBytes:buf length:dataSize];
    
    if ( outBytesRead != NULL )
    {
        NSUInteger bytesRead = result.length + 4; // include length of size count byte
        *outBytesRead = ( 4 * ceil( bytesRead / 4.0 ) ); // round up to a multiple of 32 bits
    }
    
    return result;
}

#pragma mark - deprecations

+ (nullable NSData *) dataWithOSCBlobBytes:(const char *)buf maxLength:(NSUInteger)maxLength length:(NSUInteger *)outLength
{
    return [NSData dataWithOSCBlobBytes:buf maxLength:maxLength bytesRead:outLength];
}

@end

NS_ASSUME_NONNULL_END
