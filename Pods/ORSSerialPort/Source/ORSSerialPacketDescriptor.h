//
//  ORSSerialPacketDescriptor.h
//  ORSSerialPort
//
//  Created by Andrew Madsen on 7/21/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//
//	Permission is hereby granted, free of charge, to any person obtaining a
//	copy of this software and associated documentation files (the
//	"Software"), to deal in the Software without restriction, including
//	without limitation the rights to use, copy, modify, merge, publish,
//	distribute, sublicense, and/or sell copies of the Software, and to
//	permit persons to whom the Software is furnished to do so, subject to
//	the following conditions:
//
//	The above copyright notice and this permission notice shall be included
//	in all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//	OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//	IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//	CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//	TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//	SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import <Foundation/Foundation.h>

// Keep older versions of the compiler happy
#ifndef NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
#define nullable
#define nonnullable
#define __nullable
#endif

#ifndef NS_DESIGNATED_INITIALIZER
#define NS_DESIGNATED_INITIALIZER
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * Block that parses input data and returns YES if inputData consists of a valid packet, or NO
 * if inputData doesn't contain a valid packet.
 */
typedef BOOL(^ORSSerialPacketEvaluator)(NSData * __nullable inputData);

/**
 *  An instance of ORSSerialPacketDescriptor is used to describe a packet format. ORSSerialPort
 *  can use these to "packetize" incoming data. Normally, bytes received by a serial port are
 *  delivered as they are received, often one or two bytes at a time. Responsibility for buffering
 *  incoming bytes, determining when a complete packet has been received, then parsing and processing
 *  the packet is left to the client of ORSSerialPort.
 *
 *  Rather than writing manual buffering and packet checking code, one or more packet descriptors
 *  can be installed on the port, and the port will call the -serialPort:didReceivePacket:matchingDescriptor:
 *  method on its delegate when a complete packet is received.
 *
 *  Note that this packet listener API is intended to be used with data that is sent by a serial device periodically,
 *  or in response to real world events, rather than in response to serial requests sent by the computer.
 *  For systems where a request is sent out, then a response is received, see the higher-level request/response API
 *  (ORSSerialRequest, etc.) which is built on top of the packet parsing API.
 *
 *  For more information about ORSSerialPort's packet descriptor API, see the ORSSerialPort Packet Parsing
 *  Programming Guide at
 */
@interface ORSSerialPacketDescriptor : NSObject

/**
 *  Creates an initializes an ORSSerialPacketDescriptor instance using a response evaluator block.
 *
 *  This initializer can be used to creat a packet descriptor with complex packet matching
 *  rules. For most packet formats, the initializers that take prefix and suffix, or regular expression
 *  are easier to use. However, if the packet format cannot be described using a simple prefix/suffix
 *  or regular expression, a response evaulator block containing arbitrary validation code can be
 *  provided instead.
 *
 *  @param maxPacketLength The maximum length of a valid packet. This value _must_ be correctly specified.
 *  @param userInfo          An arbitrary userInfo object.
 *  @param responseEvaluator A block used to evaluate whether received data constitutes a valid packet.
 *
 *  @return An initizliaized ORSSerialPacketDesciptor instance.
 *
 *  @see -initWithPrefix:suffix:maximumPacketLength:userInfo:
 *  @see -initWithPrefixString:suffixString:maximumPacketLength:userInfo:
 *  @see -initWithRegularExpression:maximumPacketLength:userInfo:
 */
- (instancetype)initWithMaximumPacketLength:(NSUInteger)maxPacketLength
								   userInfo:(nullable id)userInfo
						  responseEvaluator:(ORSSerialPacketEvaluator)responseEvaluator NS_DESIGNATED_INITIALIZER;

/**
 *	Creates an initializes an ORSSerialPacketDescriptor instance using fixed packet data.
 *
 *  This can be used to create a packet descriptor for packets which consist of a fixed sequence of data.
 *
 *  @param packetData	An NSData instance containing a fixed sequence of bytes making up a packet.
 *  @param userInfo		An arbitrary userInfo object. May be nil.
 *
 *  @return An initizliaized ORSSerialPacketDesciptor instance.
 */
- (instancetype)initWithPacketData:(NSData *)packetData userInfo:(nullable id)userInfo;

/**
 *  Creates an initializes an ORSSerialPacketDescriptor instance using a prefix and/or suffix.
 *
 *  If the packet format uses printable ASCII characters,
 *  -initWithPrefixString:suffixString:maximumPacketLength:userInfo: may be more suitable.
 *
 *  @note Either prefix or suffix may be nil, but not both. If the suffix is nil,
 *  packets will be considered to consist solely of prefix. If either value is nil, packets
 *  will be considred to consist soley of the the non-nil value.
 *
 *  @param prefix   An NSData instance containing a fixed packet prefix. May be nil.
 *  @param suffix   An NSData instance containing a fixed packet suffix. May be nil.
 *  @param maxPacketLength The maximum length of a valid packet. This value _must_ be correctly specified.
 *  @param userInfo An arbitrary userInfo object. May be nil.
 *
 *  @return An initizliaized ORSSerialPacketDesciptor instance.
 *
 *  @see -initWithPrefixString:suffixString:userInfo:
 */
- (instancetype)initWithPrefix:(nullable NSData *)prefix
						suffix:(nullable NSData *)suffix
		   maximumPacketLength:(NSUInteger)maxPacketLength
					  userInfo:(nullable id)userInfo;

/**
 *  Creates an initializes an ORSSerialPacketDescriptor instance using a prefix string and/or suffix string.
 *
 *  This method assumes that prefixString and suffixString are ASCII or UTF8 strings.
 *  If the packet format does not use printable ASCII characters, -initWithPrefix:suffix:maximumPacketLength:userInfo:
 *  may be more suitable.
 *
 *  @note Either prefixString or suffixString may be nil, but not both. If the suffix is nil,
 *  packets will be considered to consist solely of prefix. If either value is nil, packets
 *  will be considred to consist soley of the the non-nil value.
 *
 *  @param prefixString A fixed packet prefix string. May be nil.
 *  @param suffixString A fixed packet suffix string. May be nil.
 *  @param maxPacketLength The maximum length of a valid packet. This value _must_ be correctly specified.
 *  @param userInfo     An arbitrary userInfo object. May be nil.
 *
 *  @return An initizliaized ORSSerialPacketDesciptor instance.
 *
 *  @see -initWithPrefix:suffix:maximumPacketLength:userInfo:
 */
- (instancetype)initWithPrefixString:(nullable NSString *)prefixString
						suffixString:(nullable NSString *)suffixString
				 maximumPacketLength:(NSUInteger)maxPacketLength
							userInfo:(nullable id)userInfo;

/**
 *  Creates an initializes an ORSSerialPacketDescriptor instance using a regular expression.
 *
 *  A packet is considered valid as long as it contains at least one match for the provided
 *  regular expression. For this reason, the regex should match as conservatively (smallest match) as possible.
 *
 *  Packets described by descriptors created using this method are assumed to be ASCII or UTF8 strings.
 *  If your packets are not naturally represented as strings, consider using
 *  -initWithMaximumPacketLength:userInfo:responseEvaluator: instead.
 *
 *  @param regex    An NSRegularExpression instance for which valid packets are a match.
 *  @param maxPacketLength The maximum length of a valid packet. This value _must_ be correctly specified.
 *  @param userInfo An arbitrary userInfoObject. May be nil.
 *
 *  @return An initizliaized ORSSerialPacketDesciptor instance.
 */
- (instancetype)initWithRegularExpression:(NSRegularExpression *)regex
					  maximumPacketLength:(NSUInteger)maxPacketLength
								 userInfo:(nullable id)userInfo;

/**
 *  Can be used to determine if a block of data is a valid packet matching the descriptor encapsulated
 *  by the receiver.
 *
 *  @param packetData Data received from a serial port.
 *
 *  @return YES if the data is a valid packet, NO otherwise.
 */
- (BOOL)dataIsValidPacket:(nullable NSData *)packetData;

/**
 *  Can be used to determine and extract a packet from a buffer, matching up to the end of the buffer.
 *
 *  @param buffer Data received from serial port.
 *
 *  @return Data corresponding to valid packet, or nil.
 */
- (nullable NSData *)packetMatchingAtEndOfBuffer:(nullable NSData *)buffer;

/**
 *  The fixed packetData for packets described by the receiver. Will be nil for packet
 *  descriptors not created using -initWithPacketData:userInfo:
 */
@property (nonatomic, strong, readonly, nullable) NSData *packetData;

/**
 *  The prefix for packets described by the receiver. Will be nil for packet
 *  descriptors not created using one of the prefix/suffix initializer methods.
 */
@property (nonatomic, strong, readonly, nullable) NSData *prefix;

/**
 *  The suffix for packets described by the receiver. Will be nil for packet
 *  descriptors not created using one of the prefix/suffix initializer methods.
 */
@property (nonatomic, strong, readonly, nullable) NSData *suffix;

/**
 *  A regular expression matching packets described by the receiver. Will be nil
 *  for packet descriptors not created using -initWithRegularExpression:userInfo:.
 */
@property (nonatomic, strong, readonly, nullable) NSRegularExpression *regularExpression;

/**
 *  The maximum lenght of a packet described by the receiver.
 */
@property (nonatomic, readonly) NSUInteger maximumPacketLength;

/**
 *  Arbitrary object (e.g. NSDictionary) used to store additional data
 *  about the packet descriptor.
 */
@property (nonatomic, strong, readonly, nullable) id userInfo;

/**
 *  Unique identifier for the descriptor.
 */
@property (nonatomic, strong, readonly) NSUUID *uuid;

@end

NS_ASSUME_NONNULL_END