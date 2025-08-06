//
//  F53OSCSocket.h
//
//  Created by Christopher Ashworth on 1/28/13.
//
//  Copyright (c) 2013-2020 Figure 53 LLC, https://figure53.com
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import <Foundation/Foundation.h>

#import "GCDAsyncSocket.h"
#import "GCDAsyncUdpSocket.h"


NS_ASSUME_NONNULL_BEGIN

#define F53_OSC_SOCKET_DEBUG 0

@class F53OSCPacket;

///
///  F53OSCStats tracks socket behavior over time.
///

@interface F53OSCStats : NSObject

- (double) totalBytes;
- (double) bytesPerSecond;       // as calculated over the last second
- (void) addBytes:(double)bytes;

@end


///
///  An F53OSCSocket object represents either a TCP socket or UDP socket, but never both at the same time.
///

@interface F53OSCSocket : NSObject

+ (F53OSCSocket *) socketWithTcpSocket:(GCDAsyncSocket *)socket;
+ (F53OSCSocket *) socketWithUdpSocket:(GCDAsyncUdpSocket *)socket;

- (instancetype) initWithTcpSocket:(GCDAsyncSocket *)socket;
- (instancetype) initWithUdpSocket:(GCDAsyncUdpSocket *)socket;

@property (strong, readonly, nullable) GCDAsyncSocket *tcpSocket;
@property (strong, readonly, nullable) GCDAsyncUdpSocket *udpSocket;
@property (nonatomic, readonly) BOOL isTcpSocket;
@property (nonatomic, readonly) BOOL isUdpSocket;

@property (nonatomic, copy, nullable) NSString *interface;
@property (nonatomic, copy, nullable) NSString *host;
@property (nonatomic, assign) UInt16 port;
@property (nonatomic, getter=isIPv6Enabled) BOOL IPv6Enabled;

@property (strong, readonly, nullable) F53OSCStats *stats;

- (BOOL) startListening;
- (void) stopListening;

- (BOOL) connect;       // when using TCP, returns NO if already connected
- (void) disconnect;
- (BOOL) isConnected;

- (void) sendPacket:(F53OSCPacket *)packet;

@end

NS_ASSUME_NONNULL_END
