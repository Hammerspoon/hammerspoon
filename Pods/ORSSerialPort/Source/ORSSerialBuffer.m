//
//  ORSSerialBuffer.m
//  ORSSerialPort
//
//  Created by Andrew Madsen on 9/6/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

#import "ORSSerialBuffer.h"

@interface ORSSerialBuffer ()

@property (nonatomic, strong) NSMutableData *internalBuffer;

@end

@implementation ORSSerialBuffer

- (instancetype)init NS_UNAVAILABLE
{
	[NSException raise:NSInternalInconsistencyException format:@"Use -[ORSSerialBuffer initWithMaximumLength:]"];
	return nil;
}

- (instancetype)initWithMaximumLength:(NSUInteger)maxLength
{
	self = [super init];
	if (self) {
		_internalBuffer = [NSMutableData data];
		_maximumLength = maxLength;
	}
	return self;
}

- (void)appendData:(NSData *)data
{
	[self willChangeValueForKey:@"internalBuffer"];
	[self.internalBuffer appendData:data];
	if ([self.internalBuffer length] > self.maximumLength) {
		NSRange rangeToDelete = NSMakeRange(0, [self.internalBuffer length] - self.maximumLength);
		[self.internalBuffer replaceBytesInRange:rangeToDelete withBytes:NULL length:0];
	}
	[self didChangeValueForKey:@"internalBuffer"];
}

- (void)clearBuffer
{
	self.internalBuffer = [NSMutableData data];
}

#pragma mark - Properties

+ (NSSet *)keyPathsForValuesAffectingData { return [NSSet setWithObjects:@"internalData", nil]; }
- (NSData *)data { return self.internalBuffer; }

@end
