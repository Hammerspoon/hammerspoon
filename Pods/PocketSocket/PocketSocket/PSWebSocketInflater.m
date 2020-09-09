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

#import "PSWebSocketInflater.h"
#import "PSWebSocketInternal.h"
#import <zlib.h>

@interface PSWebSocketInflater() {
    NSInteger _windowBits;
    uint8_t _chunkBuffer[16384];
    z_stream _stream;
    BOOL _ready;

    NSMutableData *_buffer;
}
@end
@implementation PSWebSocketInflater

#pragma mark - Initialization

- (instancetype)initWithWindowBits:(NSInteger)windowBits {
    if((self = [super init])) {
        _windowBits = windowBits;
        [self reset];
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
    int ret;
    do {
        // set output properties
        _stream.avail_out = (uInt)sizeof(_chunkBuffer);
        _stream.next_out = (Bytef *)_chunkBuffer;
        
        // inflate and check status
        ret = inflate(&_stream, Z_SYNC_FLUSH);
        if(ret == Z_NEED_DICT || ret == Z_DATA_ERROR || ret == Z_MEM_ERROR) {
            PSWebSocketSetOutError(outError, PSWebSocketStatusCodeProtocolError, @"Failed to inflate bytes");
            return NO;
        }
        
        // determine number of bytes inflated
        uInt gotBack = sizeof(_chunkBuffer) - _stream.avail_out;
        if(gotBack > 0) {
            [_buffer appendBytes:_chunkBuffer length:gotBack];
        }
    } while(_stream.avail_out == 0);
    
    return YES;
}
- (BOOL)end:(NSError *__autoreleasing *)outError {
    uint8_t finish[4] = {0x00, 0x00, 0xff, 0xff};
    return [self appendBytes:finish length:sizeof(finish) error:outError];
}
- (void)reset {
    if(_ready) {
        _buffer = nil;
        inflateEnd(&_stream);
        bzero(&_stream, sizeof(_stream));
        bzero(_chunkBuffer, sizeof(_chunkBuffer));
        _ready = NO;
    }
}

#pragma mark - Private

- (BOOL)ensureReady:(NSError *__autoreleasing *)outError {
    if(!_ready) {
        if(inflateInit2(&_stream, -MAX_WBITS) != Z_OK) {
            PSWebSocketSetOutError(outError, PSWebSocketStatusCodeProtocolError, @"Failed to initialize inflate stream");
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
