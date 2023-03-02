//
//  NSString+F53OSCString.m
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

#import "NSString+F53OSCString.h"


NS_ASSUME_NONNULL_BEGIN

@implementation NSString (F53OSCStringAdditions)

- (NSData *) oscStringData
{
    //  A note on the 4s: For OSC, strings are all null-terminated and in multiples of 4 bytes.
    //  If the data is already a multiple of 4 bytes, it needs to have four null bytes appended.
    
    NSUInteger length = [self lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    NSUInteger stringLength = length;
    const char *bytes = [self cStringUsingEncoding:NSUTF8StringEncoding];
    length = 4 * ( ceil( (length + 1) / 4.0 ) );

    char *string = malloc( length * sizeof( char ) );
    NSUInteger i;
    for ( i = 0; i < stringLength; i++ )
        string[i] = bytes[i];
    for ( ; i < length; i++ )
        string[i] = 0;
         
    NSData *data = [NSData dataWithBytes:string length:length];
    free( string );
    return data;
}

///
///  An OSC string is a sequence of non-null ASCII characters followed by a null,
///  followed by 0-3 additional null characters to make the total number of bits a multiple of 32.
///
+ (nullable NSString *) stringWithOSCStringBytes:(const char *)buf maxLength:(NSUInteger)maxLength bytesRead:(out NSUInteger *)outBytesRead
{
    if ( buf == NULL || maxLength == 0 )
    {
        if ( outBytesRead != NULL )
            *outBytesRead = 0;
        return nil;
    }
    
    for ( NSUInteger index = 0; index < maxLength; index++ )
    {
        if ( buf[index] == 0 )
            goto valid; // found a NULL character within the buffer
    }
    
    // Buffer wasn't null terminated, so it's not a valid OSC string.
    if ( outBytesRead != NULL )
        *outBytesRead = 0;
    return nil;
    
valid:;
    
    NSString *result = [NSString stringWithUTF8String:buf];
    
    if ( outBytesRead != NULL )
    {
        NSUInteger bytesRead = result.length + 1; // include length of null terminator character
        *outBytesRead = 4 * ceil( bytesRead / 4.0 ); // round up to a multiple of 32 bits
    }
    
    return result;
}

///
///  Regex docs: http://userguide.icu-project.org/strings/regexp#TOC-Regular-Expression-Metacharacters
///  OSC docs: http://opensoundcontrol.org/spec-1_0
///
+ (NSString *) stringWithSpecialRegexCharactersEscaped:(NSString *)string
{
    string = [string stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]; // Do this first!
    string = [string stringByReplacingOccurrencesOfString:@"+" withString:@"\\+"];
    string = [string stringByReplacingOccurrencesOfString:@"-" withString:@"\\-"];
    string = [string stringByReplacingOccurrencesOfString:@"(" withString:@"\\("];
    string = [string stringByReplacingOccurrencesOfString:@")" withString:@"\\)"];
    string = [string stringByReplacingOccurrencesOfString:@"^" withString:@"\\^"];
    string = [string stringByReplacingOccurrencesOfString:@"$" withString:@"\\$"];
    string = [string stringByReplacingOccurrencesOfString:@"|" withString:@"\\|"];
    string = [string stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
    return string;
}

#pragma mark - deprecations

+ (nullable NSString *) stringWithOSCStringBytes:(const char *)buf maxLength:(NSUInteger)maxLength length:(NSUInteger *)outLength
{
    return [NSString stringWithOSCStringBytes:buf maxLength:maxLength bytesRead:outLength];
}


@end

NS_ASSUME_NONNULL_END
