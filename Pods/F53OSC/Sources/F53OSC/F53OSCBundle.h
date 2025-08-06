//
//  F53OSCBundle.h
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

#import <Foundation/Foundation.h>
#import "F53OSCPacket.h"

@class F53OSCTimeTag;


NS_ASSUME_NONNULL_BEGIN

@interface F53OSCBundle : F53OSCPacket

+ (nullable F53OSCBundle *) bundleWithString:(NSString *)qscString;
+ (F53OSCBundle *) bundleWithTimeTag:(F53OSCTimeTag *)timeTag
                            elements:(NSArray<NSData *> *)elements; ///< Elements must be an array of NSData objects; convert F53OSCMessages using their packetData method.

@property (strong) F53OSCTimeTag *timeTag;
@property (strong) NSArray<NSData *> *elements;

// redeclare as nonnull for this subclass
- (NSData *) packetData;

@end

NS_ASSUME_NONNULL_END
