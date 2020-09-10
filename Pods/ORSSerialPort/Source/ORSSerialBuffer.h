//
//  ORSSerialBuffer.h
//  ORSSerialPort
//
//  Created by Andrew Madsen on 9/6/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

#import <Foundation/Foundation.h>

// Keep older versions of the compiler happy
#ifndef NS_DESIGNATED_INITIALIZER
#define NS_DESIGNATED_INITIALIZER
#endif

@interface ORSSerialBuffer : NSObject

- (instancetype)initWithMaximumLength:(NSUInteger)maxLength NS_DESIGNATED_INITIALIZER;

- (void)appendData:(NSData *)data;
- (void)clearBuffer;

@property (nonatomic, strong, readonly) NSData *data;
@property (nonatomic, readonly) NSUInteger maximumLength;

@end
