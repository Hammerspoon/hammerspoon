//
//  NSNumber+F53OSCNumber.m
//
//  Created by Siobhán Dougall on 3/23/11.
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

#import "NSNumber+F53OSCNumber.h"


NS_ASSUME_NONNULL_BEGIN

@implementation NSNumber (F53OSCNumberAdditions)

- (SInt32) oscFloatValue
{
    Float32 floatValue = [self floatValue];
    SInt32 intValue = *((SInt32 *)(&floatValue));
    return OSSwapHostToBigInt32( intValue );
}

- (SInt32) oscIntValue
{
    return OSSwapHostToBigInt32([self integerValue]);
}

+ (nullable NSNumber *) numberWithOSCFloatBytes:(const char *)buf maxLength:(NSUInteger)maxLength
{
    if ( buf == NULL || maxLength < sizeof( SInt32 ) )
        return nil;
    
    SInt32 intValue = *((SInt32 *)buf);
    intValue = OSSwapBigToHostInt32( intValue );
    Float32 floatValue = *((Float32 *)&intValue);
    return [NSNumber numberWithFloat:floatValue];
}

+ (nullable NSNumber *) numberWithOSCIntBytes:(const char *)buf maxLength:(NSUInteger)maxLength
{
    if ( buf == NULL || maxLength < sizeof( SInt32 ) )
        return nil;
    
    SInt32 intValue = *((SInt32 *)buf);
    intValue = OSSwapBigToHostInt32( intValue );
    return [NSNumber numberWithInteger:intValue];
}

@end

NS_ASSUME_NONNULL_END
