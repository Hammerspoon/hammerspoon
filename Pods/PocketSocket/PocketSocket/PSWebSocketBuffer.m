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

#import "PSWebSocketBuffer.h"

@interface PSWebSocketBuffer() {
    NSMutableData *_data;
}

@end
@implementation PSWebSocketBuffer

#pragma mark - Initialization

- (instancetype)init {
    if((self = [super init])) {
        _data = [NSMutableData data];
        _offset = 0;
        _compactionLength = 4096;
    }
    return self;
}

#pragma mark - Actions

- (BOOL)hasBytesAvailable {
    return _data.length > _offset;
}
- (NSUInteger)bytesAvailable {
    if(_data.length > _offset) {
        return _data.length - _offset;
    }
    return 0;
}
- (void)appendData:(NSData *)data {
    [_data appendData:data];
}
- (void)appendBytes:(const void *)bytes length:(NSUInteger)length {
    [_data appendBytes:bytes length:length];
}
- (void)compact {
    if(_offset > _compactionLength && _offset > (_data.length >> 1)) {
        _data = [NSMutableData dataWithBytes:(char *)_data.bytes + _offset
                                      length:_data.length - _offset];
        _offset = 0;
    }
}
- (void)reset {
    _offset = 0;
    _data.length = 0;
}
- (const void *)bytes {
    return _data.bytes + _offset;
}
- (void *)mutableBytes {
    return _data.mutableBytes + _offset;
}
- (NSData *)data {
    return [_data copy];
}


@end
