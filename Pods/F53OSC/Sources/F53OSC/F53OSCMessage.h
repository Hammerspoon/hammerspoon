//
//  F53OSCMessage.h
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
#import "F53OSCFoundationAdditions.h"

///
///  Example usage:
///
///  F53OSCMessage *msg = [F53OSCMessage messageWithAddressPattern:@"/address/of/thing" 
///                                                      arguments:[NSArray arrayWithObjects:
///                                                                 [NSNumber numberWithInteger:x],
///                                                                 [NSNumber numberWithFloat:y],
///                                                                 @"z",
///                                                                 nil]];
///

NS_ASSUME_NONNULL_BEGIN

@interface F53OSCMessage : F53OSCPacket <NSSecureCoding, NSCopying>

+ (BOOL) legalAddressComponent:(nullable NSString *)addressComponent;
+ (BOOL) legalAddress:(nullable NSString *)address;
+ (BOOL) legalMethod:(nullable NSString *)method;

+ (nullable F53OSCMessage *) messageWithString:(NSString *)qscString;
+ (F53OSCMessage *) messageWithAddressPattern:(NSString *)addressPattern
                                    arguments:(NSArray *)arguments;
+ (F53OSCMessage *) messageWithAddressPattern:(NSString *)addressPattern
                                    arguments:(NSArray *)arguments
                                  replySocket:(nullable F53OSCSocket *)replySocket;

@property (nonatomic, copy) NSString *addressPattern;
@property (nonatomic, strong) NSString *typeTagString;   ///< This is normally constructed from the incoming arguments array.
@property (nonatomic, strong) NSArray *arguments;        ///< May contain NSString, NSData, NSNumber, or F53OSCValue objects. This could be extended in the future, but this covers the required types for OSC 1.0 and OSC 1.1 (with the exception of "timetag").
@property (nonatomic, strong, nullable) id userData;

- (NSArray *) addressParts;

// redeclare as nonnull for this subclass
- (NSData *) packetData;
- (NSString *) asQSC;

@end

@protocol F53OSCPacketDestination <NSObject> // ought to have called this F53OSCMessageDestination, alas

- (void)takeMessage:(nullable F53OSCMessage *)message;

@end

NS_ASSUME_NONNULL_END
