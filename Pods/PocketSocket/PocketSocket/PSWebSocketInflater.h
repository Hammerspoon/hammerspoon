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

@interface PSWebSocketInflater : NSObject

#pragma mark - Initialization

- (instancetype)initWithWindowBits:(NSInteger)windowBits;

#pragma mark - Actions

- (BOOL)begin:(NSMutableData *)buffer error:(NSError *__autoreleasing *)outError;
- (BOOL)appendBytes:(const void *)bytes length:(NSUInteger)length error:(NSError *__autoreleasing *)outError;
- (BOOL)end:(NSError *__autoreleasing *)outError;
- (void)reset;

@end
