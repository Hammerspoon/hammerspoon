//
//  ORSSerialRequest.h
//  ORSSerialPort
//
//  Created by Andrew Madsen on 4/21/14.
//  Copyright (c) 2014 Andrew Madsen. All rights reserved.
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
#import "ORSSerialPacketDescriptor.h"

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
 *  An ORSSerialRequest encapsulates a generic "request" command sent via the serial
 *  port. 
 *  
 *  An ORSSerialRequest includes data to be sent out via the serial port.
 *  It also can contain a block which is used to evaluate received
 *  data to determine if/when a valid response to the request has been received from
 *  the device on the other end of the port. Arbitrary information can be
 *  associated with the ORSSerialRequest via its userInfo property.
 */
@interface ORSSerialRequest : NSObject

/**
 *  Creates and initializes an ORSSerialRequest instance.
 *
 *  @param dataToSend			The data to be sent on the serial port.
 *  @param userInfo				An arbitrary userInfo object.
 *  @param timeout				The maximum amount of time in seconds to wait for a response. Pass -1.0 to wait indefinitely.
 *  @param responseDescriptor	A packet descriptor used to evaluate whether received data constitutes a valid response to the request.
 *  May be nil. If responseDescriptor is nil, the request is assumed not to require a response, and the next request in the queue will
 *  be sent immediately.
 *
 *  @return An initialized ORSSerialRequest instance.
 */
+ (instancetype)requestWithDataToSend:(NSData *)dataToSend
							 userInfo:(nullable id)userInfo
					  timeoutInterval:(NSTimeInterval)timeout
					responseDescriptor:(nullable ORSSerialPacketDescriptor *)responseDescriptor;

/**
 *  Initializes an ORSSerialRequest instance.
 *
 *  @param dataToSend			The data to be sent on the serial port.
 *  @param userInfo				An arbitrary userInfo object.
 *  @param timeout				The maximum amount of time in seconds to wait for a response. Pass -1.0 to wait indefinitely.
 *  @param responseDescriptor	A packet descriptor used to evaluate whether received data constitutes a valid response to the request.
 *  May be nil. If responseDescriptor is nil, the request is assumed not to require a response, and the next request in the queue will
 *  be sent immediately.
 *
 *  @return An initialized ORSSerialRequest instance.
 */
- (instancetype)initWithDataToSend:(NSData *)dataToSend
						  userInfo:(nullable id)userInfo
				   timeoutInterval:(NSTimeInterval)timeout
				 responseDescriptor:(nullable ORSSerialPacketDescriptor *)responseDescriptor;

/**
 *  Data to be sent on the serial port when the receiver is sent.
 */
@property (nonatomic, strong, readonly) NSData *dataToSend;

/**
 *  Arbitrary object (e.g. NSDictionary) used to store additional data
 *  about the request.
 */
@property (nonatomic, strong, readonly, nullable) id userInfo;

/**
 *  The maximum amount of time to wait for a response before timing out.
 *  Negative values indicate that serial port will wait forever for a response
 *  without timing out.
 */
@property (nonatomic, readonly) NSTimeInterval timeoutInterval;

/**
 *  The descriptor describing the receiver's expected response.
 */
@property (nonatomic, strong, readonly, nullable) ORSSerialPacketDescriptor *responseDescriptor;

/**
 *  Unique identifier for the request.
 */
@property (nonatomic, strong, readonly) NSString *UUIDString;

@end

#pragma mark - Deprecated

@interface ORSSerialRequest (Deprecated)

/**
 *  @deprecated Use +requestWithDataToSend:userInfo:timeoutInterval:responseDescriptor: instead.
 *
 *  Creates and initializes an ORSSerialRequest instance.
 *
 *  @param dataToSend        The data to be sent on the serial port.
 *  @param userInfo          An arbitrary userInfo object.
 *  @param timeout			 The maximum amount of time in seconds to wait for a response. Pass -1.0 to wait indefinitely.
 *  @param responseEvaluator A block used to evaluate whether received data constitutes a valid response to the request.
 *  May be nil. If responseEvaluator is nil, the request is assumed not to require a response, and the next request in the queue will
 *  be sent immediately.
 *
 *  @return An initialized ORSSerialRequest instance.
 */
+ (instancetype)requestWithDataToSend:(NSData *)dataToSend
							 userInfo:(nullable id)userInfo
					  timeoutInterval:(NSTimeInterval)timeout
					responseEvaluator:(nullable ORSSerialPacketEvaluator)responseEvaluator DEPRECATED_ATTRIBUTE;

/**
 *  @deprecated Use -initWithDataToSend:userInfo:timeoutInterval:responseDescriptor: instead.
 *  Initializes an ORSSerialRequest instance.
 *
 *  @param dataToSend        The data to be sent on the serial port.
 *  @param userInfo          An arbitrary userInfo object.
 *  @param timeout			 The maximum amount of time in seconds to wait for a response. Pass -1.0 to wait indefinitely.
 *  @param responseEvaluator A block used to evaluate whether received data constitutes a valid response to the request.
 *  May be nil. If responseEvaluator is nil, the request is assumed not to require a response, and the next request in the queue will
 *  be sent immediately.
 *
 *  @return An initialized ORSSerialRequest instance.
 */
- (instancetype)initWithDataToSend:(NSData *)dataToSend
						  userInfo:(nullable id)userInfo
				   timeoutInterval:(NSTimeInterval)timeout
				 responseEvaluator:(nullable ORSSerialPacketEvaluator)responseEvaluator DEPRECATED_ATTRIBUTE;

/**
 *  @deprecated Use the receiver's responseDescriptor object's -dataIsValidPacket: method instead.
 *  Except in the special case where the response descriptor is nil, this method now simply calls
 *  through to that.
 *
 *  Can be used to determine if a block of data is a valid response to the request encapsulated
 *  by the receiver. If the receiver doesn't have a response descriptor, this method
 *  always returns YES.
 *
 *  @param responseData Data received from a serial port.
 *
 *  @return YES if the data is a valid response, NO otherwise.
 */
- (BOOL)dataIsValidResponse:(nullable NSData *)responseData DEPRECATED_ATTRIBUTE;

@end

NS_ASSUME_NONNULL_END

