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


@interface PSWebSocketBuffer : NSObject

#pragma mark - Properties

@property (nonatomic, assign) NSInteger offset;
@property (nonatomic, assign) NSUInteger compactionLength;

#pragma mark - Actions

- (BOOL)hasBytesAvailable;
- (NSUInteger)bytesAvailable;
- (void)appendData:(NSData *)data;
- (void)appendBytes:(const void *)bytes length:(NSUInteger)length;
- (void)compact;
- (void)reset;
- (const void *)bytes;
- (void *)mutableBytes;
- (NSData *)data;

@end
