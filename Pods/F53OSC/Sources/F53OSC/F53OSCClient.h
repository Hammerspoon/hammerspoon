//
//  F53OSCClient.h
//
//  Created by Siobhán Dougall on 1/20/11.
//
//  Copyright (c) 2011-2020 Figure 53 LLC, https://figure53.com
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

#import "F53OSCSocket.h"
#import "F53OSCPacket.h"
#import "F53OSCMessage.h"

@protocol F53OSCClientDelegate;


NS_ASSUME_NONNULL_BEGIN

#define F53_OSC_CLIENT_DEBUG 0

@interface F53OSCClient : NSObject <NSSecureCoding, GCDAsyncSocketDelegate, GCDAsyncUdpSocketDelegate>

@property (nonatomic, weak)                     id<F53OSCClientDelegate> delegate;
@property (nonatomic, strong, null_resettable)  dispatch_queue_t socketDelegateQueue; // defaults to main queue
@property (nonatomic, copy, nullable)           NSString *interface;
@property (nonatomic, copy, nullable)           NSString *host;
@property (nonatomic, assign)                   UInt16 port;
@property (nonatomic, getter=isIPv6Enabled)     BOOL IPv6Enabled; // default NO
@property (nonatomic, assign)                   BOOL useTcp;
@property (nonatomic, strong, nullable)         id userData;
@property (nonatomic, copy)                     NSDictionary *state;
@property (nonatomic, readonly)                 NSString *title;
@property (nonatomic, readonly)                 BOOL isValid;
@property (nonatomic, readonly)                 BOOL isConnected;

- (BOOL) connect;   // NOTE: returns NO if internal F53OSCSocket uses TCP and is already connected
- (void) disconnect;

- (void) sendPacket:(F53OSCPacket *)packet;

@end

@protocol F53OSCClientDelegate <F53OSCPacketDestination>

@optional
- (void) clientDidConnect:(F53OSCClient *)client;
- (void) clientDidDisconnect:(F53OSCClient *)client;

@end

NS_ASSUME_NONNULL_END
