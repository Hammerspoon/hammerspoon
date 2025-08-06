//
//  F53OSCSocket.m
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

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import "F53OSCSocket.h"

#import "F53OSCPacket.h"


NS_ASSUME_NONNULL_BEGIN

#define TIMEOUT         3

#define END             0300    /* indicates end of packet */
#define ESC             0333    /* indicates byte stuffing */
#define ESC_END         0334    /* ESC ESC_END means END data byte */
#define ESC_ESC         0335    /* ESC ESC_ESC means ESC data byte */

#pragma mark - F53OSCStats

@interface F53OSCStats ()

@property (strong) NSDate *currentTime;
@property (strong) dispatch_queue_t timerQueue;
@property (assign) bool stopCounting;

@property (assign) double totalBytes;
@property (assign) double bytesPerSecond;
@property (assign) double currentBytes;

@end

@implementation F53OSCStats

- (instancetype) init
{
    self = [super init];
    if ( self )
    {
        self.totalBytes = 0;
        self.bytesPerSecond = 0;
        self.currentBytes = 0;
        self.currentTime = [NSDate date];

        self.stopCounting = NO;
        self.timerQueue = dispatch_queue_create("com.figure53.F53OSCStats", NULL);
        // keep timer on background thread
        dispatch_async(self.timerQueue, ^{
            [self countBytes];
        });
    }
    return self;
}

- (void) countBytes
{
    @synchronized ( self )
    {
        NSDate *checkTime = [NSDate date];
        if ( [checkTime timeIntervalSince1970] - [self.currentTime timeIntervalSince1970] >= 1.0 )
        {
#if F53_OSC_SOCKET_DEBUG
            NSLog( @"[F53OSCStats] UDP Bytes: %f per second, %f total", self.currentBytes, self.totalBytes );
#endif
            self.currentTime = checkTime;
            self.bytesPerSecond = self.currentBytes;
            self.currentBytes = 0;
        }

        if ( !self.stopCounting )
        {
            // trigger again after delay
            int64_t delay = 0.2 * NSEC_PER_SEC;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay), self.timerQueue, ^{
                [self countBytes];
            });
        }
    }
}

- (void) addBytes:(double)bytes
{
    @synchronized ( self )
    {
        self.totalBytes += bytes;
        self.currentBytes += bytes;
    }
}

- (void) stop
{
    self.stopCounting = YES;
}

@end

#pragma mark - F53OSCSocket

@interface F53OSCSocket ()

@property (strong, readwrite, nullable) GCDAsyncSocket *tcpSocket;
@property (strong, readwrite, nullable) GCDAsyncUdpSocket *udpSocket;
@property (strong, readwrite, nullable) F53OSCStats *stats;

@end

@implementation F53OSCSocket

+ (F53OSCSocket *) socketWithTcpSocket:(GCDAsyncSocket *)socket
{
    return [[F53OSCSocket alloc] initWithTcpSocket:socket];
}

+ (F53OSCSocket *) socketWithUdpSocket:(GCDAsyncUdpSocket *)socket
{
    return [[F53OSCSocket alloc] initWithUdpSocket:socket];
}

- (instancetype) initWithTcpSocket:(GCDAsyncSocket *)socket
{
    self = [super init];
    if ( self )
    {
        self.tcpSocket = socket;
        self.udpSocket = nil;
        self.interface = nil;
        self.host = @"localhost";
        self.port = 0;
    }
    return self;
}

- (instancetype) initWithUdpSocket:(GCDAsyncUdpSocket *)socket
{
    self = [super init];
    if ( self )
    {
        if ( !socket.isIPv6Enabled )
            [socket setPreferIPv4]; // prevents socket from selecting an IPv6 resolved address after a DNS lookup
        else
            [socket setIPVersionNeutral];
        
        self.tcpSocket = nil;
        self.udpSocket = socket;
        self.interface = nil;
        self.host = @"localhost";
        self.port = 0;
        self.stats = nil;
    }
    return self;
}

- (void) dealloc
{
    [_tcpSocket synchronouslySetDelegate:nil delegateQueue:nil];
    [_tcpSocket disconnect];
    _tcpSocket = nil;

    [_udpSocket synchronouslySetDelegate:nil delegateQueue:nil];
    _udpSocket = nil;

    _host = nil;

    [_stats stop];
    _stats = nil;
}

- (NSString *) description
{
    if ( self.isTcpSocket )
        return [NSString stringWithFormat:@"<F53OSCSocket TCP %@:%u isConnected = %i>", self.host, self.port, self.isConnected ];
    else
        return [NSString stringWithFormat:@"<F53OSCSocket UDP %@:%u>", self.host, self.port ];
}

- (BOOL) isTcpSocket
{
    return ( self.tcpSocket != nil );
}

- (BOOL) isUdpSocket
{
    return ( self.udpSocket != nil );
}

- (BOOL) isIPv6Enabled
{
    if ( self.isTcpSocket )
        return [self.tcpSocket isIPv6Enabled];
    else // isUdpSocket
        return [self.udpSocket isIPv6Enabled];
}

- (void) setIPv6Enabled:(BOOL)IPv6Enabled
{
    [self.tcpSocket setIPv6Enabled:IPv6Enabled];
    
    [self.udpSocket setIPv6Enabled:IPv6Enabled];
    if ( !IPv6Enabled )
        [self.udpSocket setPreferIPv4]; // prevents socket from selecting an IPv6 resolved address after a DNS lookup
    else
        [self.udpSocket setIPVersionNeutral];
}

- (BOOL) startListening
{
    if ( self.tcpSocket )
    {
        return [self.tcpSocket acceptOnInterface:self.interface port:self.port error:nil];
    }

    if ( self.udpSocket )
    {
        if ( [self.udpSocket bindToPort:self.port interface:self.interface error:nil] )
        {
            if ( !self.stats )
                self.stats = [[F53OSCStats alloc] init];
            return [self.udpSocket beginReceiving:nil];
        }
        else
        {
            return NO;
        }
    }

    return NO;
}

- (void) stopListening
{
    if ( self.tcpSocket )
        [self.tcpSocket disconnectAfterWriting];

    if ( self.udpSocket )
    {
        [self.udpSocket close];
        [self.stats stop];
        self.stats = nil;
    }
}

- (BOOL) connect
{
    if ( self.tcpSocket )
    {
        if ( self.host && self.port )
            return [self.tcpSocket connectToHost:self.host onPort:self.port viaInterface:self.interface withTimeout:-1 error:nil]; // NOTE: this returns NO if the GCDAsyncSocket is already connected
        else
            return NO;
    }

    if ( self.udpSocket )
        return YES;

    return NO;
}

- (void) disconnect
{
    [self.tcpSocket disconnect];
}

- (BOOL) isConnected
{
    if ( self.tcpSocket )
        return [self.tcpSocket isConnected];

    if ( self.udpSocket )
        return YES;

    return NO;
}

- (void) sendPacket:(F53OSCPacket *)packet
{
#if F53_OSC_SOCKET_DEBUG
    NSLog( @"%@ sending packet: %@", self, packet );
#endif

    if ( packet == nil )
        return;

    NSData *data = [packet packetData];

    //NSLog( @"%@ sending message with native length: %li", self, [data length] );

    if ( self.tcpSocket )
    {
        // Outgoing OSC messages are framed using the double END SLIP protocol: http://www.rfc-editor.org/rfc/rfc1055.txt

        NSMutableData *slipData = [NSMutableData data];
        Byte esc_end[2] = {ESC, ESC_END};
        Byte esc_esc[2] = {ESC, ESC_ESC};
        Byte end[1] = {END};

        [slipData appendBytes:end length:1];
        NSUInteger length = [data length];
        const Byte *buffer = [data bytes];
        for ( NSUInteger index = 0; index < length; index++ )
        {
            if ( buffer[index] == END )
                [slipData appendBytes:esc_end length:2];
            else if ( buffer[index] == ESC )
                [slipData appendBytes:esc_esc length:2];
            else
                [slipData appendBytes:&(buffer[index]) length:1];
        }
        [slipData appendBytes:end length:1];

        [self.tcpSocket writeData:slipData withTimeout:TIMEOUT tag:[slipData length]];
    }
    else if ( self.udpSocket )
    {
        NSError *error = nil;
        if ( self.interface )
        {
            // Port 0 means that the OS should choose a random ephemeral port for this socket.
            [self.udpSocket bindToPort:0 interface:self.interface error:&error];

            if ( error )
            {
                NSLog( @"Warning: %@ unable to bind interface %@ - %@", self, self.interface, [error localizedDescription] );
                return;
            }
        }

        if ( ![self.udpSocket enableBroadcast:YES error:&error] )
        {
            NSString *errString = error ? [error localizedDescription] : @"(unknown error)";
            NSLog( @"Warning: %@ unable to enable UDP broadcast - %@", self, errString );
        }
        
        if ( self.host )
            [self.udpSocket sendData:data toHost:(NSString * _Nonnull)self.host port:self.port withTimeout:TIMEOUT tag:0];
        
        [self.udpSocket closeAfterSending];
    }
}

@end

NS_ASSUME_NONNULL_END
