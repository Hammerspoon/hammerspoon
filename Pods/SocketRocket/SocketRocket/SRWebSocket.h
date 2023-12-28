//
// Copyright 2012 Square Inc.
// Portions Copyright (c) 2016-present, Facebook, Inc.
//
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree. An additional grant
// of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SRReadyState) {
    SR_CONNECTING   = 0,
    SR_OPEN         = 1,
    SR_CLOSING      = 2,
    SR_CLOSED       = 3,
};

typedef NS_ENUM(NSInteger, SRStatusCode) {
    // 0-999: Reserved and not used.
    SRStatusCodeNormal = 1000,
    SRStatusCodeGoingAway = 1001,
    SRStatusCodeProtocolError = 1002,
    SRStatusCodeUnhandledType = 1003,
    // 1004 reserved.
    SRStatusNoStatusReceived = 1005,
    SRStatusCodeAbnormal = 1006,
    SRStatusCodeInvalidUTF8 = 1007,
    SRStatusCodePolicyViolated = 1008,
    SRStatusCodeMessageTooBig = 1009,
    SRStatusCodeMissingExtension = 1010,
    SRStatusCodeInternalError = 1011,
    SRStatusCodeServiceRestart = 1012,
    SRStatusCodeTryAgainLater = 1013,
    // 1014: Reserved for future use by the WebSocket standard.
    SRStatusCodeTLSHandshake = 1015,
    // 1016-1999: Reserved for future use by the WebSocket standard.
    // 2000-2999: Reserved for use by WebSocket extensions.
    // 3000-3999: Available for use by libraries and frameworks. May not be used by applications. Available for registration at the IANA via first-come, first-serve.
    // 4000-4999: Available for use by applications.
};

@class SRWebSocket;
@class SRSecurityPolicy;

/**
 Error domain used for errors reported by SRWebSocket.
 */
extern NSString *const SRWebSocketErrorDomain;

/**
 Key used for HTTP status code if bad response was received from the server.
 */
extern NSString *const SRHTTPResponseErrorKey;

@protocol SRWebSocketDelegate;

///--------------------------------------
#pragma mark - SRWebSocket
///--------------------------------------

/**
 A `SRWebSocket` object lets you connect, send and receive data to a remote Web Socket.
 */
@interface SRWebSocket : NSObject <NSStreamDelegate>

/**
 The delegate of the web socket.

 The web socket delegate is notified on all state changes that happen to the web socket.
 */
@property (nonatomic, weak) id <SRWebSocketDelegate> delegate;

/**
 A dispatch queue for scheduling the delegate calls. The queue doesn't need be a serial queue.

 If `nil` and `delegateOperationQueue` is `nil`, the socket uses main queue for performing all delegate method calls.
 */
@property (nullable, nonatomic, strong) dispatch_queue_t delegateDispatchQueue;

/**
 An operation queue for scheduling the delegate calls.

 If `nil` and `delegateOperationQueue` is `nil`, the socket uses main queue for performing all delegate method calls.
 */
@property (nullable, nonatomic, strong) NSOperationQueue *delegateOperationQueue;

/**
 Current ready state of the socket. Default: `SR_CONNECTING`.

 This property is Key-Value Observable and fully thread-safe.
 */
@property (atomic, assign, readonly) SRReadyState readyState;

/**
 An instance of `NSURL` that this socket connects to.
 */
@property (nullable, nonatomic, strong, readonly) NSURL *url;

/**
 All HTTP headers that were received by socket or `nil` if none were received so far.
 */
@property (nullable, nonatomic, assign, readonly) CFHTTPMessageRef receivedHTTPHeaders;

/**
 Array of `NSHTTPCookie` cookies to apply to the connection.
 */
@property (nullable, nonatomic, copy) NSArray<NSHTTPCookie *> *requestCookies;

/**
 The negotiated web socket protocol or `nil` if handshake did not yet complete.
 */
@property (nullable, nonatomic, copy, readonly) NSString *protocol;

/**
 A boolean value indicating whether this socket will allow connection without SSL trust chain evaluation.
 For DEBUG builds this flag is ignored, and SSL connections are allowed regardless of the certificate trust configuration
 */
@property (nonatomic, assign, readonly) BOOL allowsUntrustedSSLCertificates;

///--------------------------------------
#pragma mark - Constructors
///--------------------------------------

/**
 Initializes a web socket with a given `NSURLRequest`.

 @param request Request to initialize with.
 */
- (instancetype)initWithURLRequest:(NSURLRequest *)request;

/**
 Initializes a web socket with a given `NSURLRequest`, specifying a transport security policy (e.g. SSL configuration).

 @param request        Request to initialize with.
 @param securityPolicy Policy object describing transport security behavior.
 */
- (instancetype)initWithURLRequest:(NSURLRequest *)request securityPolicy:(SRSecurityPolicy *)securityPolicy;

/**
 Initializes a web socket with a given `NSURLRequest` and list of sub-protocols.

 @param request   Request to initialize with.
 @param protocols An array of strings that turn into `Sec-WebSocket-Protocol`. Default: `nil`.
 */
- (instancetype)initWithURLRequest:(NSURLRequest *)request protocols:(nullable NSArray<NSString *> *)protocols;

/**
 Initializes a web socket with a given `NSURLRequest`, list of sub-protocols and whether untrusted SSL certificates are allowed.

 @param request                        Request to initialize with.
 @param protocols                      An array of strings that turn into `Sec-WebSocket-Protocol`. Default: `nil`.
 @param allowsUntrustedSSLCertificates Boolean value indicating whether untrusted SSL certificates are allowed. Default: `false`.
 */
- (instancetype)initWithURLRequest:(NSURLRequest *)request protocols:(nullable NSArray<NSString *> *)protocols allowsUntrustedSSLCertificates:(BOOL)allowsUntrustedSSLCertificates
    DEPRECATED_MSG_ATTRIBUTE("Disabling certificate chain validation is unsafe. "
                             "Please use a proper Certificate Authority to issue your TLS certificates.");

/**
 Initializes a web socket with a given `NSURLRequest`, list of sub-protocols and whether untrusted SSL certificates are allowed.

 @param request        Request to initialize with.
 @param protocols      An array of strings that turn into `Sec-WebSocket-Protocol`. Default: `nil`.
 @param securityPolicy Policy object describing transport security behavior.
 */
- (instancetype)initWithURLRequest:(NSURLRequest *)request protocols:(nullable NSArray<NSString *> *)protocols securityPolicy:(SRSecurityPolicy *)securityPolicy NS_DESIGNATED_INITIALIZER;

/**
 Initializes a web socket with a given `NSURL`.

 @param url URL to initialize with.
 */
- (instancetype)initWithURL:(NSURL *)url;

/**
 Initializes a web socket with a given `NSURL` and list of sub-protocols.

 @param url       URL to initialize with.
 @param protocols An array of strings that turn into `Sec-WebSocket-Protocol`. Default: `nil`.
 */
- (instancetype)initWithURL:(NSURL *)url protocols:(nullable NSArray<NSString *> *)protocols;

/**
 Initializes a web socket with a given `NSURL`, specifying a transport security policy (e.g. SSL configuration).

 @param url            URL to initialize with.
 @param securityPolicy Policy object describing transport security behavior.
 */
- (instancetype)initWithURL:(NSURL *)url securityPolicy:(SRSecurityPolicy *)securityPolicy;

/**
 Initializes a web socket with a given `NSURL`, list of sub-protocols and whether untrusted SSL certificates are allowed.

 @param url                            URL to initialize with.
 @param protocols                      An array of strings that turn into `Sec-WebSocket-Protocol`. Default: `nil`.
 @param allowsUntrustedSSLCertificates Boolean value indicating whether untrusted SSL certificates are allowed. Default: `false`.
 */
- (instancetype)initWithURL:(NSURL *)url protocols:(nullable NSArray<NSString *> *)protocols allowsUntrustedSSLCertificates:(BOOL)allowsUntrustedSSLCertificates
    DEPRECATED_MSG_ATTRIBUTE("Disabling certificate chain validation is unsafe. "
                             "Please use a proper Certificate Authority to issue your TLS certificates.");

/**
 Unavailable initializer. Please use any other initializer.
 */
- (instancetype)init NS_UNAVAILABLE;

/**
 Unavailable constructor. Please use any other initializer.
 */
+ (instancetype)new NS_UNAVAILABLE;

///--------------------------------------
#pragma mark - Schedule
///--------------------------------------

/**
 Schedules a received on a given run loop in a given mode.
 By default, a web socket will schedule itself on `+[NSRunLoop SR_networkRunLoop]` using `NSDefaultRunLoopMode`.

 @param runLoop The run loop on which to schedule the receiver.
 @param mode     The mode for the run loop.
 */
- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode NS_SWIFT_NAME(schedule(in:forMode:));

/**
 Removes the receiver from a given run loop running in a given mode.

 @param runLoop The run loop on which the receiver was scheduled.
 @param mode    The mode for the run loop.
 */
- (void)unscheduleFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode NS_SWIFT_NAME(unschedule(from:forMode:));

///--------------------------------------
#pragma mark - Open / Close
///--------------------------------------

/**
 Opens web socket, which will trigger connection, authentication and start receiving/sending events.
 An instance of `SRWebSocket` is intended for one-time-use only. This method should be called once and only once.
 */
- (void)open;

/**
 Closes a web socket using `SRStatusCodeNormal` code and no reason.
 */
- (void)close;

/**
 Closes a web socket using a given code and reason.

 @param code   Code to close the socket with.
 @param reason Reason to send to the server or `nil`.
 */
- (void)closeWithCode:(NSInteger)code reason:(nullable NSString *)reason;

///--------------------------------------
#pragma mark Send
///--------------------------------------

/**
 Send a UTF-8 string or binary data to the server.

 @param message UTF-8 String or Data to send.

 @deprecated Please use `sendString:` or `sendData` instead.
 */
- (void)send:(nullable id)message __attribute__((deprecated("Please use `sendString:error:` or `sendData:error:` instead.")));

/**
 Send a UTF-8 String to the server.

 @param string String to send.
 @param error  On input, a pointer to variable for an `NSError` object.
 If an error occurs, this pointer is set to an `NSError` object containing information about the error.
 You may specify `nil` to ignore the error information.

 @return `YES` if the string was scheduled to send, otherwise - `NO`.
 */
- (BOOL)sendString:(NSString *)string error:(NSError **)error NS_SWIFT_NAME(send(string:));

/**
 Send binary data to the server.

 @param data  Data to send.
 @param error On input, a pointer to variable for an `NSError` object.
 If an error occurs, this pointer is set to an `NSError` object containing information about the error.
 You may specify `nil` to ignore the error information.

 @return `YES` if the string was scheduled to send, otherwise - `NO`.
 */
- (BOOL)sendData:(nullable NSData *)data error:(NSError **)error NS_SWIFT_NAME(send(data:));

/**
 Send binary data to the server, without making a defensive copy of it first.

 @param data  Data to send.
 @param error On input, a pointer to variable for an `NSError` object.
 If an error occurs, this pointer is set to an `NSError` object containing information about the error.
 You may specify `nil` to ignore the error information.

 @return `YES` if the string was scheduled to send, otherwise - `NO`.
 */
- (BOOL)sendDataNoCopy:(nullable NSData *)data error:(NSError **)error NS_SWIFT_NAME(send(dataNoCopy:));

/**
 Send Ping message to the server with optional data.

 @param data  Instance of `NSData` or `nil`.
 @param error On input, a pointer to variable for an `NSError` object.
 If an error occurs, this pointer is set to an `NSError` object containing information about the error.
 You may specify `nil` to ignore the error information.

 @return `YES` if the string was scheduled to send, otherwise - `NO`.
 */
- (BOOL)sendPing:(nullable NSData *)data error:(NSError **)error NS_SWIFT_NAME(sendPing(_:));

@end

///--------------------------------------
#pragma mark - SRWebSocketDelegate
///--------------------------------------

/**
 The `SRWebSocketDelegate` protocol describes the methods that `SRWebSocket` objects
 call on their delegates to handle status and messsage events.
 */
@protocol SRWebSocketDelegate <NSObject>

@optional

#pragma mark Receive Messages

/**
 Called when any message was received from a web socket.
 This method is suboptimal and might be deprecated in a future release.

 @param webSocket An instance of `SRWebSocket` that received a message.
 @param message   Received message. Either a `String` or `NSData`.
 */
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message;

/**
 Called when a frame was received from a web socket.

 @param webSocket An instance of `SRWebSocket` that received a message.
 @param string    Received text in a form of UTF-8 `String`.
 */
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessageWithString:(NSString *)string;

/**
 Called when a frame was received from a web socket.

 @param webSocket An instance of `SRWebSocket` that received a message.
 @param data      Received data in a form of `NSData`.
 */
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessageWithData:(NSData *)data;

#pragma mark Status & Connection

/**
 Called when a given web socket was open and authenticated.

 @param webSocket An instance of `SRWebSocket` that was open.
 */
- (void)webSocketDidOpen:(SRWebSocket *)webSocket;

/**
 Called when a given web socket encountered an error.

 @param webSocket An instance of `SRWebSocket` that failed with an error.
 @param error     An instance of `NSError`.
 */
- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error;

/**
 Called when a given web socket was closed.

 @param webSocket An instance of `SRWebSocket` that was closed.
 @param code      Code reported by the server.
 @param reason    Reason in a form of a String that was reported by the server or `nil`.
 @param wasClean  Boolean value indicating whether a socket was closed in a clean state.
 */
- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(nullable NSString *)reason wasClean:(BOOL)wasClean;

/**
 Called on receive of a ping message from the server.

 @param webSocket An instance of `SRWebSocket` that received a ping frame.
 @param data      Payload that was received or `nil` if there was no payload.
 */
- (void)webSocket:(SRWebSocket *)webSocket didReceivePingWithData:(nullable NSData *)data;

/**
 Called when a pong data was received in response to ping.

 @param webSocket An instance of `SRWebSocket` that received a pong frame.
 @param pongData  Payload that was received or `nil` if there was no payload.
 */
- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(nullable NSData *)pongData;

/**
 Sent before reporting a text frame to be able to configure if it shuold be convert to a UTF-8 String or passed as `NSData`.
 If the method is not implemented - it will always convert text frames to String.

 @param webSocket An instance of `SRWebSocket` that received a text frame.

 @return `YES` if text frame should be converted to UTF-8 String, otherwise - `NO`. Default: `YES`.
 */
- (BOOL)webSocketShouldConvertTextFrameToString:(SRWebSocket *)webSocket NS_SWIFT_NAME(webSocketShouldConvertTextFrameToString(_:));

@end

NS_ASSUME_NONNULL_END
