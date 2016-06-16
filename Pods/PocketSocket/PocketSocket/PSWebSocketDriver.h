//  Copyright 2014-Present Zwopple Limited
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import <Foundation/Foundation.h>
#import "PSWebSocketTypes.h"

@class PSWebSocketDriver;

@protocol PSWebSocketDriverDelegate <NSObject>

@required

- (void)driverDidOpen:(PSWebSocketDriver *)driver;
- (void)driver:(PSWebSocketDriver *)driver didReceiveMessage:(id)message;
- (void)driver:(PSWebSocketDriver *)driver didReceivePing:(NSData *)ping;
- (void)driver:(PSWebSocketDriver *)driver didReceivePong:(NSData *)pong;
- (void)driver:(PSWebSocketDriver *)driver didFailWithError:(NSError *)error;
- (void)driver:(PSWebSocketDriver *)driver didCloseWithCode:(NSInteger)code reason:(NSString *)reason;
- (void)driver:(PSWebSocketDriver *)driver write:(NSData *)data;

@end
@interface PSWebSocketDriver : NSObject

#pragma mark - Class Methods

+ (BOOL)isWebSocketRequest:(NSURLRequest *)request;
+ (NSError *)errorWithCode:(NSInteger)code reason:(NSString *)reason;

#pragma mark - Properties

@property (nonatomic, assign, readonly) PSWebSocketMode mode;
@property (nonatomic, weak) id <PSWebSocketDriverDelegate> delegate;

@property (nonatomic, strong) NSString *protocol;

#pragma mark - Initialization

+ (instancetype)clientDriverWithRequest:(NSURLRequest *)request;
+ (instancetype)serverDriverWithRequest:(NSURLRequest *)request;

#pragma mark - Actions

- (void)start;
- (void)sendText:(NSString *)text;
- (void)sendBinary:(NSData *)binary;
- (void)sendCloseCode:(NSInteger)code reason:(NSString *)reason;
- (void)sendPing:(NSData *)data;
- (void)sendPong:(NSData *)data;

- (NSUInteger)execute:(void *)bytes maxLength:(NSUInteger)maxLength;

@end
