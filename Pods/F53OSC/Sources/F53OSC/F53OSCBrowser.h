//
//  F53OSCBrowser.h
//  F53OSC
//
//  Created by Brent Lord on 8/27/20.
//  Adapted from QLKBrowser by Zach Waugh.
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

//  Browses a given domain for a given service type.
//  Creates an F53OSCClientRecord for each host found advertising that service.
//  Retains the client record until the service stops advertising or browser is stopped.

#import <Foundation/Foundation.h>

@protocol F53OSCBrowserDelegate;


NS_ASSUME_NONNULL_BEGIN

@interface F53OSCClientRecord : NSObject <NSCopying>

@property (nonatomic)                   UInt16 port;
@property (nonatomic)                   BOOL useTCP;
@property (nonatomic, copy)             NSArray<NSString *> *hostAddresses;
@property (nonatomic, strong, nullable) NSNetService *netService;

@end


@interface F53OSCBrowser : NSObject

@property (nonatomic, readonly)         NSArray<F53OSCClientRecord *> *clientRecords;
@property (nonatomic, readonly)         BOOL running;
@property (nonatomic)                   BOOL useTCP;
@property (nonatomic)                   BOOL resolveIPv6Addresses; // default NO

// NOTE: changing these properties while the browser is running restarts the browser
@property (nonatomic, copy)             NSString *domain;       // default "local."
@property (nonatomic, copy)             NSString *serviceType;  // default "", must be set before starting browser

@property (nonatomic, weak)             id<F53OSCBrowserDelegate> delegate;

- (void)start NS_REQUIRES_SUPER;
- (void)stop NS_REQUIRES_SUPER;

@end


@protocol F53OSCBrowserDelegate <NSObject>

- (void)browser:(F53OSCBrowser *)browser didAddClientRecord:(F53OSCClientRecord *)clientRecord;
- (void)browser:(F53OSCBrowser *)browser didRemoveClientRecord:(F53OSCClientRecord *)clientRecord;

@optional
- (BOOL)browser:(F53OSCBrowser *)browser shouldAcceptNetService:(NSNetService *)netService;

@end

NS_ASSUME_NONNULL_END
