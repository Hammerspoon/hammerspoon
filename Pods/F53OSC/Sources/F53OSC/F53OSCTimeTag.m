//
//  F53OSCTimeTag.m
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

#import "F53OSCTimeTag.h"

#import "NSDate+F53OSCTimeTag.h"


NS_ASSUME_NONNULL_BEGIN

@implementation F53OSCTimeTag

+ (F53OSCTimeTag *) timeTagWithDate:(NSDate *)date
{
    double fractionsPerSecond = (double)0xffffffff;
    F53OSCTimeTag *result = [F53OSCTimeTag new];
    double secondsSince1900 = [date timeIntervalSince1970] + 2208988800;
    result.seconds = ((UInt64)secondsSince1900) & 0xffffffff;
    result.fraction = (UInt32)( fmod( secondsSince1900, 1.0 ) * fractionsPerSecond );
    return result;
}

+ (F53OSCTimeTag *) immediateTimeTag
{
    F53OSCTimeTag *result = [F53OSCTimeTag new];
    result.seconds = 0;
    result.fraction = 1;
    return result;
}

- (NSData *) oscTimeTagData
{
    UInt32 swappedSeconds = OSSwapHostToBigInt32( self.seconds );
    UInt32 swappedFraction = OSSwapHostToBigInt32( self.fraction );
    NSMutableData *data = [NSMutableData data];
    [data appendBytes:&swappedSeconds length:sizeof( UInt32 )];
    [data appendBytes:&swappedFraction length:sizeof( UInt32 )];
    return [data copy];
}

+ (nullable F53OSCTimeTag *) timeTagWithOSCTimeBytes:(char *)buf
{
    if ( buf == NULL )
        return nil;
    
    UInt32 seconds = *((UInt32 *)buf);
    buf += sizeof( UInt32 );
    UInt32 fraction = *((UInt32 *)buf);
    
    F53OSCTimeTag *result = [[F53OSCTimeTag alloc] init];
    result.seconds = OSSwapBigToHostInt32( seconds );
    result.fraction = OSSwapBigToHostInt32( fraction );
    return result;
}

@end

NS_ASSUME_NONNULL_END
