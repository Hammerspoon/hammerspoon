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
#import <Foundation/Foundation.h>
#import "PSWebSocketTypes.h"
#import "PSWebSocketDriver.h"
#import <sys/socket.h>
#import <arpa/inet.h>


typedef NS_ENUM(uint8_t, PSWebSocketOpCode) {
    PSWebSocketOpCodeContinuation = 0x0,
    PSWebSocketOpCodeText = 0x1,
    PSWebSocketOpCodeBinary = 0x2,
    // 0x3 -> 0x7 reserved
    PSWebSocketOpCodeClose = 0x8,
    PSWebSocketOpCodePing = 0x9,
    PSWebSocketOpCodePong = 0xA,
    // 0xB -> 0xF reserved
};

static const uint8_t PSWebSocketFinMask = 0x80;
static const uint8_t PSWebSocketOpCodeMask = 0x0F;
static const uint8_t PSWebSocketRsv1Mask = 0x40;
static const uint8_t PSWebSocketRsv2Mask = 0x20;
static const uint8_t PSWebSocketRsv3Mask = 0x10;
static const uint8_t PSWebSocketMaskMask = 0x80;
static const uint8_t PSWebSocketPayloadLenMask = 0x7F;

#define PSWebSocketSetOutError(e, c, d) if(e){ *e = [PSWebSocketDriver errorWithCode:c reason:d]; }

static inline void _PSWebSocketLog(id self, NSString *format, ...) {
    __block va_list arg_list;
    va_start (arg_list, format);
    
    NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:arg_list];
    
    va_end(arg_list);
    
    NSLog(@"[%@]: %@", self, formattedString);
}
#define PSWebSocketLog(...) _PSWebSocketLog(self, __VA_ARGS__)

static inline BOOL PSWebSocketOpCodeIsControl(PSWebSocketOpCode opcode) {
    return (opcode == PSWebSocketOpCodeClose ||
            opcode == PSWebSocketOpCodePing ||
            opcode == PSWebSocketOpCodePong);
};

static inline BOOL PSWebSocketOpCodeIsValid(PSWebSocketOpCode opcode) {
    return (opcode == PSWebSocketOpCodeClose ||
            opcode == PSWebSocketOpCodePing ||
            opcode == PSWebSocketOpCodePong ||
            opcode == PSWebSocketOpCodeText ||
            opcode == PSWebSocketOpCodeBinary ||
            opcode == PSWebSocketOpCodeContinuation);
};


static inline BOOL PSWebSocketCloseCodeIsValid(NSInteger closeCode) {
    if(closeCode < 1000) {
        return NO;
    }
    if(closeCode >= 1000 && closeCode <= 1011) {
        if(closeCode == 1004 ||
           closeCode == 1005 ||
           closeCode == 1006) {
            return NO;
        }
        return YES;
    }
    if(closeCode >= 3000 && closeCode <= 3999) {
        return YES;
    }
    if(closeCode >= 4000 && closeCode <= 4999) {
        return YES;
    }
    return NO;
}

static inline NSOrderedSet* PSHTTPHeaderFieldValues(NSString *header) {
    NSMutableOrderedSet *components = [NSMutableOrderedSet orderedSet];
    [[header componentsSeparatedByString:@";"] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *str = obj;
        while ([str hasPrefix:@" "] && str.length > 1) {
            str = [str substringWithRange:NSMakeRange(1, str.length - 1)];
        }
        while ([str hasSuffix:@" "] && str.length > 1) {
            str = [str substringWithRange:NSMakeRange(0, str.length - 1)];
        }
        if ([str length] > 0 && ![str isEqualToString:@" "]) {
            [components addObject:str];
        }
    }];
    return components;
}

static inline NSData* PSPeerAddressOfInputStream(NSInputStream *stream) {
    // First recover the socket handle from the stream:
    NSData* handleData = CFBridgingRelease(CFReadStreamCopyProperty((__bridge CFReadStreamRef)stream,
                                                                    kCFStreamPropertySocketNativeHandle));
    if(!handleData || handleData.length != sizeof(CFSocketNativeHandle)) {
        return nil;
    }
    CFSocketNativeHandle socketHandle = *(const CFSocketNativeHandle*)handleData.bytes;
    struct sockaddr_in addr;
    unsigned addrLen = sizeof(addr);
    if(getpeername(socketHandle, (struct sockaddr*)&addr,&addrLen) < 0) {
        return nil;
    }
    return [NSData dataWithBytes: &addr length: addr.sin_len];
}

static inline NSString* PSPeerHostOfInputStream(NSInputStream *stream) {
    NSData *peerAddress = PSPeerAddressOfInputStream(stream);
    if(!peerAddress) {
        return nil;
    }
    const struct sockaddr_in *addr = peerAddress.bytes;
    char nameBuf[INET6_ADDRSTRLEN];
    if(inet_ntop(addr->sin_family, &addr->sin_addr, nameBuf, (socklen_t)sizeof(nameBuf)) == NULL) {
        return nil;
    }
    return [NSString stringWithFormat: @"%s:%hu", nameBuf, ntohs(addr->sin_port)];
}