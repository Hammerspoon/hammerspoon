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

#import "PSWebSocketDeflater.h"
#import "PSWebSocketDeflater.h"
#import "PSWebSocketInternal.h"
#import <zlib.h>

@interface PSWebSocketDeflater() {
    NSInteger _windowBits;
    NSUInteger _memoryLevel;
    uint8_t _chunkBuffer[16384];
    z_stream _stream;
    BOOL _ready;
    
    NSMutableData *_buffer;
}
@end
@implementation PSWebSocketDeflater

#pragma mark - Initialization

- (instancetype)initWithWindowBits:(NSInteger)windowBits memoryLevel:(NSUInteger)memoryLevel {
    if((self = [super init])) {
        _windowBits = windowBits;
        _memoryLevel = memoryLevel;
        NSAssert(_windowBits >= -15 && _windowBits <= -1, @"windowBits must be between -15 and -1");
        NSAssert(_memoryLevel >= 1 && _memoryLevel <= 9, @"memory level must be between 1 and 9");
        bzero(&_stream, sizeof(_stream));
        bzero(_chunkBuffer, sizeof(_chunkBuffer));
        _ready = NO;
    }
    return self;
}

#pragma mark - Actions

- (BOOL)begin:(NSMutableData *)buffer error:(NSError *__autoreleasing *)outError {
    NSParameterAssert(buffer);
    if(![self ensureReady:outError]) {
        return NO;
    }
    _buffer = buffer;
    return YES;
}
- (BOOL)appendBytes:(const void *)bytes length:(NSUInteger)length error:(NSError *__autoreleasing *)outError {
    NSParameterAssert(length);
    
    // set input properties
    _stream.avail_in = (uInt)length;
    _stream.next_in = (Bytef *)bytes;
    
    // inflate loop
    do {
        // set output properties
        _stream.avail_out = (uInt)sizeof(_chunkBuffer);
        _stream.next_out = (Bytef *)_chunkBuffer;
        
        deflate(&_stream, Z_SYNC_FLUSH);
        
        // determine number of bytes inflated
        uInt gotBack = sizeof(_chunkBuffer) - _stream.avail_out;
        if(gotBack > 0) {
            [_buffer appendBytes:_chunkBuffer length:gotBack];
        }
    } while(_stream.avail_out == 0);
    
    return YES;
}

- (BOOL)end:(NSError *__autoreleasing *)outError {
    if(_buffer.length > 4) {
        _buffer.length -= 4;
    } else {
        _buffer.length = 0;
    }
    return YES;
}
- (void)reset {
    if(_ready) {
        _buffer = nil;
        deflateEnd(&_stream);
        bzero(&_stream, sizeof(_stream));
        bzero(_chunkBuffer, sizeof(_chunkBuffer));
        _ready = NO;
    }
}

#pragma mark - Private

- (BOOL)ensureReady:(NSError *__autoreleasing *)outError {
    if(!_ready) {
        if(deflateInit2(&_stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, _windowBits, _memoryLevel, Z_FIXED) != Z_OK) {
            PSWebSocketSetOutError(outError, PSWebSocketStatusCodeProtocolError, @"Failed to initialize deflate stream");
            return NO;
        }
        _ready = YES;
    }
    return YES;
}

#pragma mark - Dealloc

- (void)dealloc {
    [self reset];
}


@end
