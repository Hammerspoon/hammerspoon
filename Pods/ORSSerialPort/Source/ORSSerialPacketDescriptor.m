//
//  ORSSerialPacketDescriptor.m
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

#import "ORSSerialPacketDescriptor.h"

@interface ORSSerialPacketDescriptor ()

@property (nonatomic, copy, readonly) ORSSerialPacketEvaluator responseEvaluator;

@end

@implementation ORSSerialPacketDescriptor

- (instancetype)init NS_UNAVAILABLE
{
	[NSException raise:NSInternalInconsistencyException format:@"You must initialize %@ with its designated initializers, or one of its convenience initializers.", NSStringFromClass([self class])];
	return nil;
}

- (instancetype)initWithMaximumPacketLength:(NSUInteger)maxPacketLength
								   userInfo:(id)userInfo
						  responseEvaluator:(ORSSerialPacketEvaluator)responseEvaluator
{
	self = [super init];
	if (self) {
		_maximumPacketLength = maxPacketLength;
		_userInfo = userInfo;
		_responseEvaluator = [responseEvaluator ?: ^BOOL(NSData *d){ return [d length] > 0; } copy];
		_uuid = [NSUUID UUID];
	}
	return self;
}

- (instancetype)initWithPacketData:(NSData *)packetData userInfo:(nullable id)userInfo
{
	self = [self initWithMaximumPacketLength:[packetData length] userInfo:userInfo responseEvaluator:^BOOL(NSData *inputData) {
		return [inputData isEqualToData:packetData];
	}];
	if (self) {
		_packetData = packetData;
	}
	return self;
}

- (instancetype)initWithPrefix:(NSData *)prefix
						suffix:(NSData *)suffix
		   maximumPacketLength:(NSUInteger)maxPacketLength
					  userInfo:(id)userInfo
{
	self = [self initWithMaximumPacketLength:maxPacketLength userInfo:userInfo responseEvaluator:^BOOL(NSData *data) {
		if (prefix == nil && suffix == nil) { return NO; }
		if (prefix && [prefix length] > [data length]) { return NO; }
		if (suffix && [suffix length] > [data length]) { return NO; }
		
		for (NSUInteger i=0; i<[prefix length]; i++) {
			uint8_t prefixByte = ((uint8_t *)[prefix bytes])[i];
			uint8_t dataByte = ((uint8_t *)[data bytes])[i];
			if (prefixByte != dataByte) { return NO; }
		}
		
		for (NSUInteger i=0; i<[suffix length]; i++) {
			uint8_t suffixByte = ((uint8_t *)[suffix bytes])[([suffix length]-1-i)];
			uint8_t dataByte = ((uint8_t *)[data bytes])[([data length]-1-i)];
			if (suffixByte != dataByte) { return NO; }
		}
		
		return YES;
	}];
	if (self) {
		_prefix = prefix;
		_suffix = suffix;
	}
	return self;
}

- (instancetype)initWithPrefixString:(NSString *)prefixString
						suffixString:(NSString *)suffixString
				 maximumPacketLength:(NSUInteger)maxPacketLength
							userInfo:(id)userInfo;
{
	NSData *prefixData = [prefixString dataUsingEncoding:NSUTF8StringEncoding];
	NSData *suffixData = [suffixString dataUsingEncoding:NSUTF8StringEncoding];
	return [self initWithPrefix:prefixData suffix:suffixData maximumPacketLength:maxPacketLength userInfo:userInfo];
}

- (instancetype)initWithRegularExpression:(NSRegularExpression *)regex
					  maximumPacketLength:(NSUInteger)maxPacketLength
								 userInfo:(id)userInfo;
{
	self = [self initWithMaximumPacketLength:maxPacketLength userInfo:userInfo responseEvaluator:^BOOL(NSData *data) {
		NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		if (!string) return NO;
		
		return [regex numberOfMatchesInString:string options:NSMatchingAnchored range:NSMakeRange(0, [string length])] > 0;
	}];
	if (self) {
		_regularExpression = regex;
	}
	return self;
}

- (BOOL)isEqual:(id)object
{
	if (object == self) return YES;
	if (![object isKindOfClass:[ORSSerialPacketDescriptor class]]) return NO;
	return [[(ORSSerialPacketDescriptor *)object uuid] isEqual:self.uuid];
}

- (NSUInteger)hash { return [self.uuid hash]; }

- (BOOL)dataIsValidPacket:(NSData *)packetData
{
	if (!self.responseEvaluator) return YES;
	return self.responseEvaluator(packetData);
}

- (NSData *)packetMatchingAtEndOfBuffer:(NSData *)buffer
{
	for (NSUInteger i=1; i<=[buffer length]; i++)
	{
		NSData *window = [buffer subdataWithRange:NSMakeRange([buffer length]-i, i)];
		if ([self dataIsValidPacket:window]) return window;
	}
	return nil;
}

@end
