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

#import "SRWebSocket.h"

#if __has_include(<unicode/utf8.h>)
#define HAS_ICU
#endif

#ifdef HAS_ICU
#import <unicode/utf8.h>
#endif

#import <os/lock.h>

#import "SRDelegateController.h"
#import "SRIOConsumer.h"
#import "SRIOConsumerPool.h"
#import "SRHash.h"
#import "SRURLUtilities.h"
#import "SRError.h"
#import "NSURLRequest+SRWebSocket.h"
#import "NSRunLoop+SRWebSocket.h"
#import "SRProxyConnect.h"
#import "SRSecurityPolicy.h"
#import "SRHTTPConnectMessage.h"
#import "SRRandom.h"
#import "SRLog.h"
#import "SRMutex.h"
#import "SRSIMDHelpers.h"
#import "NSURLRequest+SRWebSocketPrivate.h"
#import "NSRunLoop+SRWebSocketPrivate.h"
#import "SRConstants.h"

#if !__has_feature(objc_arc)
#error SocketRocket must be compiled with ARC enabled
#endif

__attribute__((used)) static void importCategories(void)
{
    import_NSURLRequest_SRWebSocket();
    import_NSRunLoop_SRWebSocket();
}

typedef struct {
    BOOL fin;
    //  BOOL rsv1;
    //  BOOL rsv2;
    //  BOOL rsv3;
    uint8_t opcode;
    BOOL masked;
    uint64_t payload_length;
} frame_header;

static NSString *const SRWebSocketAppendToSecKeyString = @"258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

static inline int32_t validate_dispatch_data_partial_string(NSData *data);

static uint8_t const SRWebSocketProtocolVersion = 13;

NSString *const SRWebSocketErrorDomain = @"SRWebSocketErrorDomain";
NSString *const SRHTTPResponseErrorKey = @"HTTPResponseStatusCode";

@interface SRWebSocket ()  <NSStreamDelegate>

@property (atomic, assign, readwrite) SRReadyState readyState;

// Specifies whether SSL trust chain should NOT be evaluated.
// By default this flag is set to NO, meaning only secure SSL connections are allowed.
// For DEBUG builds this flag is ignored, and SSL connections are allowed regardless
// of the certificate trust configuration
@property (nonatomic, assign, readwrite) BOOL allowsUntrustedSSLCertificates;

@property (nonatomic, strong, readonly) SRDelegateController *delegateController;

@end

@implementation SRWebSocket {
    SRMutex _kvoLock;
    os_unfair_lock _propertyLock;

    dispatch_queue_t _workQueue;
    NSMutableArray<SRIOConsumer *> *_consumers;

    NSInputStream *_inputStream;
    NSOutputStream *_outputStream;

    dispatch_data_t _readBuffer;
    NSUInteger _readBufferOffset;

    dispatch_data_t _outputBuffer;
    NSUInteger _outputBufferOffset;

    uint8_t _currentFrameOpcode;
    size_t _currentFrameCount;
    size_t _readOpCount;
    uint32_t _currentStringScanPosition;
    NSMutableData *_currentFrameData;

    NSString *_closeReason;

    NSString *_secKey;

    SRSecurityPolicy *_securityPolicy;
    BOOL _requestRequiresSSL;
    BOOL _streamSecurityValidated;

    uint8_t _currentReadMaskKey[4];
    size_t _currentReadMaskOffset;

    BOOL _closeWhenFinishedWriting;
    BOOL _failed;

    NSURLRequest *_urlRequest;

    BOOL _sentClose;
    BOOL _didFail;
    BOOL _cleanupScheduled;
    int _closeCode;

    BOOL _isPumping;

    NSMutableSet<NSArray *> *_scheduledRunloops; // Set<[RunLoop, Mode]>. TODO: (nlutsenko) Fix clowntown

    // We use this to retain ourselves.
    __strong SRWebSocket *_selfRetain;

    NSArray<NSString *> *_requestedProtocols;
    SRIOConsumerPool *_consumerPool;

    // proxy support
    SRProxyConnect *_proxyConnect;
}

@synthesize readyState = _readyState;

///--------------------------------------
#pragma mark - Init
///--------------------------------------

- (instancetype)initWithURLRequest:(NSURLRequest *)request protocols:(NSArray<NSString *> *)protocols securityPolicy:(SRSecurityPolicy *)securityPolicy
{
    self = [super init];
    if (!self) return self;

    assert(request.URL);
    _url = request.URL;
    _urlRequest = request;
    _requestedProtocols = [protocols copy];
    _securityPolicy = securityPolicy;
    _requestRequiresSSL = SRURLRequiresSSL(_url);

    _readyState = SR_CONNECTING;

    _propertyLock = OS_UNFAIR_LOCK_INIT;
    _kvoLock = SRMutexInitRecursive();
    _workQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);

    // Going to set a specific on the queue so we can validate we're on the work queue
    dispatch_queue_set_specific(_workQueue, (__bridge void *)self, (__bridge void *)(_workQueue), NULL);

    _delegateController = [[SRDelegateController alloc] init];

    _readBuffer = dispatch_data_empty;
    _outputBuffer = dispatch_data_empty;

    _currentFrameData = [[NSMutableData alloc] init];

    _consumers = [[NSMutableArray alloc] init];

    _consumerPool = [[SRIOConsumerPool alloc] init];

    _scheduledRunloops = [[NSMutableSet alloc] init];

    return self;
}

- (instancetype)initWithURLRequest:(NSURLRequest *)request protocols:(NSArray<NSString *> *)protocols allowsUntrustedSSLCertificates:(BOOL)allowsUntrustedSSLCertificates
{
    SRSecurityPolicy *securityPolicy;
    NSArray *pinnedCertificates = request.SR_SSLPinnedCertificates;
    if (pinnedCertificates) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
        securityPolicy = [SRSecurityPolicy pinnningPolicyWithCertificates:pinnedCertificates];
#pragma clang diagnostic pop
    } else {
        BOOL certificateChainValidationEnabled = !allowsUntrustedSSLCertificates;
    securityPolicy = [[SRSecurityPolicy alloc] initWithCertificateChainValidationEnabled:certificateChainValidationEnabled];
    }

    return [self initWithURLRequest:request protocols:protocols securityPolicy:securityPolicy];
}

- (instancetype)initWithURLRequest:(NSURLRequest *)request securityPolicy:(SRSecurityPolicy *)securityPolicy
{
    return [self initWithURLRequest:request protocols:nil securityPolicy:securityPolicy];
}

- (instancetype)initWithURLRequest:(NSURLRequest *)request protocols:(NSArray<NSString *> *)protocols
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    return [self initWithURLRequest:request protocols:protocols allowsUntrustedSSLCertificates:NO];
#pragma clang diagnostic pop
}

- (instancetype)initWithURLRequest:(NSURLRequest *)request
{
    return [self initWithURLRequest:request protocols:nil];
}

- (instancetype)initWithURL:(NSURL *)url
{
    return [self initWithURL:url protocols:nil];
}

- (instancetype)initWithURL:(NSURL *)url protocols:(NSArray<NSString *> *)protocols
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    return [self initWithURL:url protocols:protocols allowsUntrustedSSLCertificates:NO];
#pragma clang diagnostic pop
}

- (instancetype)initWithURL:(NSURL *)url securityPolicy:(SRSecurityPolicy *)securityPolicy
{
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    return [self initWithURLRequest:request protocols:nil securityPolicy:securityPolicy];
}

- (instancetype)initWithURL:(NSURL *)url protocols:(NSArray<NSString *> *)protocols allowsUntrustedSSLCertificates:(BOOL)allowsUntrustedSSLCertificates
{
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    return [self initWithURLRequest:request protocols:protocols allowsUntrustedSSLCertificates:allowsUntrustedSSLCertificates];
}

- (void)assertOnWorkQueue
{
    assert(dispatch_get_specific((__bridge void *)self) == (__bridge void *)_workQueue);
}

///--------------------------------------
#pragma mark - Dealloc
///--------------------------------------

- (void)dealloc
{
    _inputStream.delegate = nil;
    _outputStream.delegate = nil;

    [_inputStream close];
    [_outputStream close];

    if (_receivedHTTPHeaders) {
        CFRelease(_receivedHTTPHeaders);
        _receivedHTTPHeaders = NULL;
    }

    SRMutexDestroy(_kvoLock);
}

///--------------------------------------
#pragma mark - Accessors
///--------------------------------------

#pragma mark readyState

- (void)setReadyState:(SRReadyState)readyState
{
    @try {
        SRMutexLock(_kvoLock);
        if (_readyState != readyState) {
            [self willChangeValueForKey:@"readyState"];
            os_unfair_lock_lock(&_propertyLock);
            _readyState = readyState;
            os_unfair_lock_unlock(&_propertyLock);
            [self didChangeValueForKey:@"readyState"];
        }
    }
    @finally {
        SRMutexUnlock(_kvoLock);
    }
}

- (SRReadyState)readyState
{
    SRReadyState state = 0;
    os_unfair_lock_lock(&_propertyLock);
    state = _readyState;
    os_unfair_lock_unlock(&_propertyLock);
    return state;
}

+ (BOOL)automaticallyNotifiesObserversOfReadyState {
    return NO;
}

///--------------------------------------
#pragma mark - Open / Close
///--------------------------------------

- (void)open
{
    NSURL* const url = _url;
    if (!url) {
        NSError *error = SRErrorWithDomainCodeDescription(NSURLErrorDomain, NSURLErrorBadURL, @"Unable to open socket with emtpy URL.");
        [self _failWithError:error];
        return;
    }
    NSAssert(self.readyState == SR_CONNECTING, @"Cannot call -(void)open on SRWebSocket more than once.");

    _selfRetain = self;

    if (_urlRequest.timeoutInterval > 0) {
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_urlRequest.timeoutInterval * NSEC_PER_SEC));
        __weak typeof(self) wself = self;
        dispatch_after(popTime, dispatch_get_main_queue(), ^{
            __strong SRWebSocket *sself = wself;
            if (!sself) {
                return;
            }
            if (sself.readyState == SR_CONNECTING) {
                NSError *error = SRErrorWithDomainCodeDescription(NSURLErrorDomain, NSURLErrorTimedOut, @"Timed out connecting to server.");
                [sself _failWithError:error];
            }
        });
    }

    _proxyConnect = [[SRProxyConnect alloc] initWithURL:url];

    __weak typeof(self) wself = self;
    [_proxyConnect openNetworkStreamWithCompletion:^(NSError *error, NSInputStream *readStream, NSOutputStream *writeStream) {
        [wself _connectionDoneWithError:error readStream:readStream writeStream:writeStream];
    }];
}

- (void)_connectionDoneWithError:(NSError *)error readStream:(NSInputStream *)readStream writeStream:(NSOutputStream *)writeStream
{
    if (error != nil) {
        [self _failWithError:error];
    } else {
        _outputStream = writeStream;
        _inputStream = readStream;

        _inputStream.delegate = self;
        _outputStream.delegate = self;
        [self _updateSecureStreamOptions];

        if (!_scheduledRunloops.count) {
            [self scheduleInRunLoop:[NSRunLoop SR_networkRunLoop] forMode:NSDefaultRunLoopMode];
        }

        // If we don't require SSL validation - consider that we connected.
        // Otherwise `didConnect` is called when SSL validation finishes.
        if (!_requestRequiresSSL) {
            dispatch_async(_workQueue, ^{
                [self didConnect];
            });
        }
    }
    // Schedule to run on a work queue, to make sure we don't run this inline and deallocate `self` inside `SRProxyConnect`.
    // TODO: (nlutsenko) Find a better structure for this, maybe Bolts Tasks?
    dispatch_async(_workQueue, ^{
        self->_proxyConnect = nil;
    });
}

- (BOOL)_checkHandshake:(CFHTTPMessageRef)httpMessage
{
    NSString *acceptHeader = CFBridgingRelease(CFHTTPMessageCopyHeaderFieldValue(httpMessage, CFSTR("Sec-WebSocket-Accept")));

    if (acceptHeader == nil) {
        return NO;
    }

    NSString *concattedString = [_secKey stringByAppendingString:SRWebSocketAppendToSecKeyString];
    NSData *hashedString = SRSHA1HashFromString(concattedString);
    NSString *expectedAccept = SRBase64EncodedStringFromData(hashedString);
    return [acceptHeader isEqualToString:expectedAccept];
}

- (void)_HTTPHeadersDidFinish:(CFHTTPMessageRef)httpMessage
{
    NSInteger responseCode = CFHTTPMessageGetResponseStatusCode(httpMessage);
    if (responseCode >= 400) {
        SRDebugLog(@"Request failed with response code %d", responseCode);
        NSError *error = SRHTTPErrorWithCodeDescription(responseCode, 2132,
                                                        [NSString stringWithFormat:@"Received bad response code from server: %d.",
                                                         (int)responseCode]);
        [self _failWithError:error];
        return;
    }

    if(![self _checkHandshake:httpMessage]) {
        NSError *error = SRErrorWithCodeDescription(2133, @"Invalid Sec-WebSocket-Accept response.");
        [self _failWithError:error];
        return;
    }

    NSString *negotiatedProtocol = CFBridgingRelease(CFHTTPMessageCopyHeaderFieldValue(httpMessage, CFSTR("Sec-WebSocket-Protocol")));
    if (negotiatedProtocol) {
        // Make sure we requested the protocol
        if ([_requestedProtocols indexOfObject:negotiatedProtocol] == NSNotFound) {
            NSError *error = SRErrorWithCodeDescription(2133, @"Server specified Sec-WebSocket-Protocol that wasn't requested.");
            [self _failWithError:error];
            return;
        }

        _protocol = negotiatedProtocol;
    }

    self.readyState = SR_OPEN;

    if (!_didFail) {
        [self _readFrameNew];
    }

    [self.delegateController performDelegateBlock:^(id<SRWebSocketDelegate>  _Nullable delegate, SRDelegateAvailableMethods availableMethods) {
        if (availableMethods.didOpen) {
            [delegate webSocketDidOpen:self];
        }
    }];
}


- (void)_readHTTPHeader
{
    if (_receivedHTTPHeaders == NULL) {
        _receivedHTTPHeaders = CFHTTPMessageCreateEmpty(NULL, NO);
    }

    [self _readUntilHeaderCompleteWithCallback:^(SRWebSocket *socket,  NSData *data) {
        if (!socket) {
            return;
        }
        CFHTTPMessageRef receivedHTTPHeaders = socket->_receivedHTTPHeaders;

        CFHTTPMessageAppendBytes(receivedHTTPHeaders, (const UInt8 *)data.bytes, data.length);

        if (CFHTTPMessageIsHeaderComplete(receivedHTTPHeaders)) {
            SRDebugLog(@"Finished reading headers %@", CFBridgingRelease(CFHTTPMessageCopyAllHeaderFields(receivedHTTPHeaders)));
            [socket _HTTPHeadersDidFinish:receivedHTTPHeaders];
        } else {
            [socket _readHTTPHeader];
        }
    }];
}

- (void)didConnect
{
    SRDebugLog(@"Connected");

    _secKey = SRBase64EncodedStringFromData(SRRandomData(16));
    assert([_secKey length] == 24);

    CFHTTPMessageRef message = SRHTTPConnectMessageCreate(_urlRequest,
                                                          _secKey,
                                                          SRWebSocketProtocolVersion,
                                                          self.requestCookies,
                                                          _requestedProtocols);

    NSData *messageData = CFBridgingRelease(CFHTTPMessageCopySerializedMessage(message));

    CFRelease(message);

    [self _writeData:messageData];
    [self _readHTTPHeader];
}

- (void)_updateSecureStreamOptions
{
    if (_requestRequiresSSL) {
        SRDebugLog(@"Setting up security for streams.");
        [_securityPolicy updateSecurityOptionsInStream:_inputStream];
        [_securityPolicy updateSecurityOptionsInStream:_outputStream];
    }

    NSString *networkServiceType = SRStreamNetworkServiceTypeFromURLRequest(_urlRequest);
    if (networkServiceType != nil) {
        [_inputStream setProperty:networkServiceType forKey:NSStreamNetworkServiceType];
        [_outputStream setProperty:networkServiceType forKey:NSStreamNetworkServiceType];
    }
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode
{
    [_outputStream scheduleInRunLoop:aRunLoop forMode:mode];
    [_inputStream scheduleInRunLoop:aRunLoop forMode:mode];

    [_scheduledRunloops addObject:@[aRunLoop, mode]];
}

- (void)unscheduleFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode
{
    [_outputStream removeFromRunLoop:aRunLoop forMode:mode];
    [_inputStream removeFromRunLoop:aRunLoop forMode:mode];

    [_scheduledRunloops removeObject:@[aRunLoop, mode]];
}

- (void)close
{
    [self closeWithCode:SRStatusCodeNormal reason:nil];
}

- (void)closeWithCode:(NSInteger)code reason:(NSString *)reason
{
    assert(code);
    __weak typeof(self) wself = self;
    dispatch_async(_workQueue, ^{
        __strong SRWebSocket *sself = wself;
        if (!sself) {
          return;
        }
        if (sself.readyState == SR_CLOSING || sself.readyState == SR_CLOSED) {
            return;
        }

        BOOL wasConnecting = sself.readyState == SR_CONNECTING;

        sself.readyState = SR_CLOSING;

        SRDebugLog(@"Closing with code %d reason %@", code, reason);

        if (wasConnecting) {
            [sself closeConnection];
            return;
        }

        size_t maxMsgSize = [reason maximumLengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        NSMutableData *mutablePayload = [[NSMutableData alloc] initWithLength:sizeof(uint16_t) + maxMsgSize];
        NSData *payload = mutablePayload;

        ((uint16_t *)mutablePayload.mutableBytes)[0] = CFSwapInt16BigToHost((uint16_t)code);

        if (reason) {
            NSRange remainingRange = {0};

            NSUInteger usedLength = 0;

            BOOL success = [reason getBytes:(char *)mutablePayload.mutableBytes + sizeof(uint16_t) maxLength:payload.length - sizeof(uint16_t) usedLength:&usedLength encoding:NSUTF8StringEncoding options:NSStringEncodingConversionExternalRepresentation range:NSMakeRange(0, reason.length) remainingRange:&remainingRange];
#pragma unused (success)

            assert(success);
            assert(remainingRange.length == 0);

            if (usedLength != maxMsgSize) {
                payload = [payload subdataWithRange:NSMakeRange(0, usedLength + sizeof(uint16_t))];
            }
        }


        [sself _sendFrameWithOpcode:SROpCodeConnectionClose data:payload];
    });
}

- (void)_closeWithProtocolError:(NSString *)message
{
    // Need to shunt this on the _callbackQueue first to see if they received any messages
    [self.delegateController performDelegateQueueBlock:^{
        [self closeWithCode:SRStatusCodeProtocolError reason:message];
        dispatch_async(self->_workQueue, ^{
            [self closeConnection];
        });
    }];
}

- (void)_failWithError:(NSError *)error
{
    dispatch_async(_workQueue, ^{
        if (self.readyState != SR_CLOSED) {
            self->_failed = YES;
            [self.delegateController performDelegateBlock:^(id<SRWebSocketDelegate>  _Nullable delegate, SRDelegateAvailableMethods availableMethods) {
                if (availableMethods.didFailWithError) {
                    [delegate webSocket:self didFailWithError:error];
                }
            }];

            self.readyState = SR_CLOSED;

            SRDebugLog(@"Failing with error %@", error.localizedDescription);

            [self closeConnection];
            [self _scheduleCleanup];
        }
    });
}

- (void)_writeData:(NSData *)data
{
    [self assertOnWorkQueue];

    if (_closeWhenFinishedWriting) {
        return;
    }

    __block NSData *strongData = data;
    dispatch_data_t newData = dispatch_data_create(data.bytes, data.length, nil, ^{
        strongData = nil;
    });
    (void)strongData;
    _outputBuffer = dispatch_data_create_concat(_outputBuffer, newData);
    [self _pumpWriting];
}

- (void)send:(nullable id)message
{
    if (!message) {
        [self sendData:nil error:nil]; // Send Data, but it doesn't matter since we are going to send the same text frame with 0 length.
    } else if ([message isKindOfClass:[NSString class]]) {
        [self sendString:(NSString *_Nonnull)message error:nil];
    } else if ([message isKindOfClass:[NSData class]]) {
        [self sendData:message error:nil];
    } else {
        NSAssert(NO, @"Unrecognized message. Not able to send anything other than a String or NSData.");
    }
}

- (BOOL)sendString:(NSString *)string error:(NSError **)error
{
    if (self.readyState != SR_OPEN) {
        NSString *message = @"Invalid State: Cannot call `sendString:error:` until connection is open.";
        if (error) {
            *error = SRErrorWithCodeDescription(2134, message);
        }
        SRDebugLog(message);
        return NO;
    }

    string = [string copy];
    dispatch_async(_workQueue, ^{
        [self _sendFrameWithOpcode:SROpCodeTextFrame data:[string dataUsingEncoding:NSUTF8StringEncoding]];
    });
    return YES;
}

- (BOOL)sendData:(nullable NSData *)data error:(NSError **)error
{
    data = [data copy];
    return [self sendDataNoCopy:data error:error];
}

- (BOOL)sendDataNoCopy:(nullable NSData *)data error:(NSError **)error
{
    if (self.readyState != SR_OPEN) {
        NSString *message = @"Invalid State: Cannot call `sendDataNoCopy:error:` until connection is open.";
        if (error) {
            *error = SRErrorWithCodeDescription(2134, message);
        }
        SRDebugLog(message);
        return NO;
    }

    dispatch_async(_workQueue, ^{
        if (data) {
            [self _sendFrameWithOpcode:SROpCodeBinaryFrame data:data];
        } else {
            [self _sendFrameWithOpcode:SROpCodeTextFrame data:nil];
        }
    });
    return YES;
}

- (BOOL)sendPing:(nullable NSData *)data error:(NSError **)error
{
    if (self.readyState != SR_OPEN) {
        NSString *message = @"Invalid State: Cannot call `sendPing:error:` until connection is open.";
        if (error) {
            *error = SRErrorWithCodeDescription(2134, message);
        }
        SRDebugLog(message);
        return NO;
    }

    data = [data copy] ?: [NSData data]; // It's okay for a ping to be empty
    dispatch_async(_workQueue, ^{
        [self _sendFrameWithOpcode:SROpCodePing data:data];
    });
    return YES;
}

- (void)_handlePingWithData:(nullable NSData *)data
{
    // Need to pingpong this off _callbackQueue first to make sure messages happen in order
    [self.delegateController performDelegateBlock:^(id<SRWebSocketDelegate> _Nullable delegate, SRDelegateAvailableMethods availableMethods) {
        if (availableMethods.didReceivePing) {
            [delegate webSocket:self didReceivePingWithData:data];
        }
        dispatch_async(self->_workQueue, ^{
            [self _sendFrameWithOpcode:SROpCodePong data:data];
        });
    }];
}

- (void)handlePong:(NSData *)pongData
{
    SRDebugLog(@"Received pong");
    [self.delegateController performDelegateBlock:^(id<SRWebSocketDelegate>  _Nullable delegate, SRDelegateAvailableMethods availableMethods) {
        if (availableMethods.didReceivePong) {
            [delegate webSocket:self didReceivePong:pongData];
        }
    }];
}


static inline BOOL closeCodeIsValid(int closeCode) {
    if (closeCode < 1000) {
        return NO;
    }

    if (closeCode >= 1000 && closeCode <= 1011) {
        if (closeCode == 1004 ||
            closeCode == 1005 ||
            closeCode == 1006) {
            return NO;
        }
        return YES;
    }

    if (closeCode >= 3000 && closeCode <= 3999) {
        return YES;
    }

    if (closeCode >= 4000 && closeCode <= 4999) {
        return YES;
    }

    return NO;
}

//  Note from RFC:
//
//  If there is a body, the first two
//  bytes of the body MUST be a 2-byte unsigned integer (in network byte
//  order) representing a status code with value /code/ defined in
//  Section 7.4.  Following the 2-byte integer the body MAY contain UTF-8
//  encoded data with value /reason/, the interpretation of which is not
//  defined by this specification.

- (void)handleCloseWithData:(NSData *)data
{
    size_t dataSize = data.length;
    __block uint16_t closeCode = 0;

    SRDebugLog(@"Received close frame");

    if (dataSize == 1) {
        // TODO handle error
        [self _closeWithProtocolError:@"Payload for close must be larger than 2 bytes"];
        return;
    } else if (dataSize >= 2) {
        [data getBytes:&closeCode length:sizeof(closeCode)];
        _closeCode = CFSwapInt16BigToHost(closeCode);
        if (!closeCodeIsValid(_closeCode)) {
            [self _closeWithProtocolError:[NSString stringWithFormat:@"Cannot have close code of %d", _closeCode]];
            return;
        }
        if (dataSize > 2) {
            _closeReason = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(2, dataSize - 2)] encoding:NSUTF8StringEncoding];
            if (!_closeReason) {
                [self _closeWithProtocolError:@"Close reason MUST be valid UTF-8"];
                return;
            }
        }
    } else {
        _closeCode = SRStatusNoStatusReceived;
    }

    [self assertOnWorkQueue];

    if (self.readyState == SR_OPEN) {
        [self closeWithCode:1000 reason:nil];
    }
    dispatch_async(_workQueue, ^{
        [self closeConnection];
    });
}

- (void)closeConnection
{
    [self assertOnWorkQueue];
    SRDebugLog(@"Trying to disconnect");
    _closeWhenFinishedWriting = YES;
    [self _pumpWriting];
}

- (void)_handleFrameWithData:(NSData *)frameData opCode:(SROpCode)opcode
{
    // Check that the current data is valid UTF8

    BOOL isControlFrame = (opcode == SROpCodePing || opcode == SROpCodePong || opcode == SROpCodeConnectionClose);
    if (isControlFrame) {
        //frameData will be copied before passing to handlers
        //otherwise there can be misbehaviours when value at the pointer is changed
        frameData = [frameData copy];

        dispatch_async(_workQueue, ^{
            [self _readFrameContinue];
        });
    } else {
        [self _readFrameNew];
    }

    switch (opcode) {
        case SROpCodeTextFrame: {
            NSString *string = [[NSString alloc] initWithData:frameData encoding:NSUTF8StringEncoding];
            if (!string && frameData) {
                [self closeWithCode:SRStatusCodeInvalidUTF8 reason:@"Text frames must be valid UTF-8."];
                dispatch_async(_workQueue, ^{
                    [self closeConnection];
                });
                return;
            }
            SRDebugLog(@"Received text message.");
            [self.delegateController performDelegateBlock:^(id<SRWebSocketDelegate>  _Nullable delegate, SRDelegateAvailableMethods availableMethods) {
                // Don't convert into string - iff `delegate` tells us not to. Otherwise - create UTF8 string and handle that.
                if (availableMethods.shouldConvertTextFrameToString && ![delegate webSocketShouldConvertTextFrameToString:self]) {
                    if (availableMethods.didReceiveMessage) {
                        [delegate webSocket:self didReceiveMessage:frameData];
                    }
                    if (availableMethods.didReceiveMessageWithData) {
                        [delegate webSocket:self didReceiveMessageWithData:frameData];
                    }
                } else {
                    if (availableMethods.didReceiveMessage) {
                        [delegate webSocket:self didReceiveMessage:string];
                    }
                    if (availableMethods.didReceiveMessageWithString) {
                        [delegate webSocket:self didReceiveMessageWithString:string];
                    }
                }
            }];
            break;
        }
        case SROpCodeBinaryFrame: {
            SRDebugLog(@"Received data message.");
            [self.delegateController performDelegateBlock:^(id<SRWebSocketDelegate>  _Nullable delegate, SRDelegateAvailableMethods availableMethods) {
                if (availableMethods.didReceiveMessage) {
                    [delegate webSocket:self didReceiveMessage:frameData];
                }
                if (availableMethods.didReceiveMessageWithData) {
                    [delegate webSocket:self didReceiveMessageWithData:frameData];
                }
            }];
        }
            break;
        case SROpCodeConnectionClose:
            [self handleCloseWithData:frameData];
            break;
        case SROpCodePing:
            [self _handlePingWithData:frameData];
            break;
        case SROpCodePong:
            [self handlePong:frameData];
            break;
        default:
            [self _closeWithProtocolError:[NSString stringWithFormat:@"Unknown opcode %ld", (long)opcode]];
            // TODO: Handle invalid opcode
            break;
    }
}

- (void)_handleFrameHeader:(frame_header)frame_header curData:(NSData *)curData
{
    assert(frame_header.opcode != 0);

    if (self.readyState == SR_CLOSED) {
        return;
    }


    BOOL isControlFrame = (frame_header.opcode == SROpCodePing || frame_header.opcode == SROpCodePong || frame_header.opcode == SROpCodeConnectionClose);

    if (isControlFrame && !frame_header.fin) {
        [self _closeWithProtocolError:@"Fragmented control frames not allowed"];
        return;
    }

    if (isControlFrame && frame_header.payload_length >= 126) {
        [self _closeWithProtocolError:@"Control frames cannot have payloads larger than 126 bytes"];
        return;
    }

    if (!isControlFrame) {
        _currentFrameOpcode = frame_header.opcode;
        _currentFrameCount += 1;
    }

    if (frame_header.payload_length == 0) {
        if (isControlFrame) {
            [self _handleFrameWithData:curData opCode:frame_header.opcode];
        } else {
            if (frame_header.fin) {
                [self _handleFrameWithData:_currentFrameData opCode:frame_header.opcode];
            } else {
                // TODO add assert that opcode is not a control;
                [self _readFrameContinue];
            }
        }
    } else {
        assert(frame_header.payload_length <= SIZE_T_MAX);
        [self _addConsumerWithDataLength:(size_t)frame_header.payload_length callback:^(SRWebSocket *sself, NSData *newData) {
            if (isControlFrame) {
                [sself _handleFrameWithData:newData opCode:frame_header.opcode];
            } else {
                if (frame_header.fin) {
                    [sself _handleFrameWithData:sself->_currentFrameData opCode:frame_header.opcode];
                } else {
                    // TODO add assert that opcode is not a control;
                    [sself _readFrameContinue];
                }
            }
        } readToCurrentFrame:!isControlFrame unmaskBytes:frame_header.masked];
    }
}

/* From RFC:

 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 +-+-+-+-+-------+-+-------------+-------------------------------+
 |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
 |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
 |N|V|V|V|       |S|             |   (if payload len==126/127)   |
 | |1|2|3|       |K|             |                               |
 +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
 |     Extended payload length continued, if payload len == 127  |
 + - - - - - - - - - - - - - - - +-------------------------------+
 |                               |Masking-key, if MASK set to 1  |
 +-------------------------------+-------------------------------+
 | Masking-key (continued)       |          Payload Data         |
 +-------------------------------- - - - - - - - - - - - - - - - +
 :                     Payload Data continued ...                :
 + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
 |                     Payload Data continued ...                |
 +---------------------------------------------------------------+
 */

static const uint8_t SRFinMask          = 0x80;
static const uint8_t SROpCodeMask       = 0x0F;
static const uint8_t SRRsvMask          = 0x70;
static const uint8_t SRMaskMask         = 0x80;
static const uint8_t SRPayloadLenMask   = 0x7F;


- (void)_readFrameContinue
{
    assert((_currentFrameCount == 0 && _currentFrameOpcode == 0) || (_currentFrameCount > 0 && _currentFrameOpcode > 0));

    [self _addConsumerWithDataLength:2 callback:^(SRWebSocket *sself, NSData *data) {
        __block frame_header header = {0};

        const uint8_t *headerBuffer = data.bytes;
        assert(data.length >= 2);

        if (headerBuffer[0] & SRRsvMask) {
            [sself _closeWithProtocolError:@"Server used RSV bits"];
            return;
        }

        uint8_t receivedOpcode = (SROpCodeMask & headerBuffer[0]);

        BOOL isControlFrame = (receivedOpcode == SROpCodePing || receivedOpcode == SROpCodePong || receivedOpcode == SROpCodeConnectionClose);

        if (!isControlFrame && receivedOpcode != 0 && sself->_currentFrameCount > 0) {
            [sself _closeWithProtocolError:@"all data frames after the initial data frame must have opcode 0"];
            return;
        }

        if (receivedOpcode == 0 && sself->_currentFrameCount == 0) {
            [sself _closeWithProtocolError:@"cannot continue a message"];
            return;
        }

        header.opcode = receivedOpcode == 0 ? sself->_currentFrameOpcode : receivedOpcode;

        header.fin = !!(SRFinMask & headerBuffer[0]);


        header.masked = !!(SRMaskMask & headerBuffer[1]);
        header.payload_length = SRPayloadLenMask & headerBuffer[1];

        headerBuffer = NULL;

        if (header.masked) {
            [sself _closeWithProtocolError:@"Client must receive unmasked data"];
            return;
        }

        size_t extra_bytes_needed = header.masked ? sizeof(sself->_currentReadMaskKey) : 0;

        if (header.payload_length == 126) {
            extra_bytes_needed += sizeof(uint16_t);
        } else if (header.payload_length == 127) {
            extra_bytes_needed += sizeof(uint64_t);
        }

        if (extra_bytes_needed == 0) {
            [sself _handleFrameHeader:header curData:sself->_currentFrameData];
        } else {
            [sself _addConsumerWithDataLength:extra_bytes_needed callback:^(SRWebSocket *eself, NSData *edata) {
                size_t mapped_size = edata.length;
#pragma unused (mapped_size)
                const void *mapped_buffer = edata.bytes;
                size_t offset = 0;

                if (header.payload_length == 126) {
                    assert(mapped_size >= sizeof(uint16_t));
                    uint16_t payloadLength = 0;
                    memcpy(&payloadLength, mapped_buffer, sizeof(uint16_t));
                    payloadLength = CFSwapInt16BigToHost(payloadLength);

                    header.payload_length = payloadLength;
                    offset += sizeof(uint16_t);
                } else if (header.payload_length == 127) {
                    assert(mapped_size >= sizeof(uint64_t));
                    uint64_t payloadLength = 0;
                    memcpy(&payloadLength, mapped_buffer, sizeof(uint64_t));
                    payloadLength = CFSwapInt64BigToHost(payloadLength);

                    header.payload_length = payloadLength;
                    offset += sizeof(uint64_t);
                } else {
                    assert(header.payload_length < 126 && header.payload_length >= 0);
                }

                if (header.masked) {
                    assert(mapped_size >= sizeof(eself->_currentReadMaskOffset) + offset);
                    memcpy(eself->_currentReadMaskKey, ((uint8_t *)mapped_buffer) + offset, sizeof(eself->_currentReadMaskKey));
                }

                [eself _handleFrameHeader:header curData:eself->_currentFrameData];
            } readToCurrentFrame:NO unmaskBytes:NO];
        }
    } readToCurrentFrame:NO unmaskBytes:NO];
}

- (void)_readFrameNew
{
    dispatch_async(_workQueue, ^{
        // Don't reset the length, since Apple doesn't guarantee that this will free the memory (and in tests on
        // some platforms, it doesn't seem to, effectively causing a leak the size of the biggest frame so far).
        self->_currentFrameData = [[NSMutableData alloc] init];

        self->_currentFrameOpcode = 0;
        self->_currentFrameCount = 0;
        self->_readOpCount = 0;
        self->_currentStringScanPosition = 0;

        [self _readFrameContinue];
    });
}

- (void)_pumpWriting
{
    [self assertOnWorkQueue];

    NSUInteger dataLength = dispatch_data_get_size(_outputBuffer);
    if (dataLength - _outputBufferOffset > 0 && _outputStream.hasSpaceAvailable) {
        __block NSInteger bytesWritten = 0;
        __block BOOL streamFailed = NO;

        dispatch_data_t dataToSend = dispatch_data_create_subrange(_outputBuffer, _outputBufferOffset, dataLength - _outputBufferOffset);
        dispatch_data_apply(dataToSend, ^bool(dispatch_data_t region, size_t offset, const void *buffer, size_t size) {
            NSInteger sentLength = [_outputStream write:buffer maxLength:size];
            if (sentLength == -1) {
                streamFailed = YES;
                return false;
            }
            bytesWritten += sentLength;
            return (sentLength >= (NSInteger)size); // If we can't write all the data into the stream - bail-out early.
        });
        if (streamFailed) {
            NSInteger code = 2145;
            NSString *description = @"Error writing to stream.";
            NSError *streamError = _outputStream.streamError;
            NSError *error = streamError ? SRErrorWithCodeDescriptionUnderlyingError(code, description, streamError) : SRErrorWithCodeDescription(code, description);
            [self _failWithError:error];
            return;
        }

        _outputBufferOffset += bytesWritten;

        if (_outputBufferOffset > SRDefaultBufferSize() && _outputBufferOffset > dataLength / 2) {
            _outputBuffer = dispatch_data_create_subrange(_outputBuffer, _outputBufferOffset, dataLength - _outputBufferOffset);
            _outputBufferOffset = 0;
        }
    }

    if (_closeWhenFinishedWriting &&
        (dispatch_data_get_size(_outputBuffer) - _outputBufferOffset) == 0 &&
        (_inputStream.streamStatus != NSStreamStatusNotOpen &&
         _inputStream.streamStatus != NSStreamStatusClosed) &&
        !_sentClose) {
        _sentClose = YES;

        @synchronized(self) {
            [_outputStream close];
            [_inputStream close];


            for (NSArray *runLoop in [_scheduledRunloops copy]) {
                [self unscheduleFromRunLoop:[runLoop objectAtIndex:0] forMode:[runLoop objectAtIndex:1]];
            }
        }

        if (!_failed) {
            [self.delegateController performDelegateBlock:^(id<SRWebSocketDelegate>  _Nullable delegate, SRDelegateAvailableMethods availableMethods) {
                if (availableMethods.didCloseWithCode) {
                    [delegate webSocket:self didCloseWithCode:self->_closeCode reason:self->_closeReason wasClean:YES];
                }
            }];
        }

        [self _scheduleCleanup];
    }
}

- (void)_addConsumerWithScanner:(stream_scanner)consumer callback:(data_callback)callback
{
    [self assertOnWorkQueue];
    [self _addConsumerWithScanner:consumer callback:callback dataLength:0];
}

- (void)_addConsumerWithDataLength:(size_t)dataLength callback:(data_callback)callback readToCurrentFrame:(BOOL)readToCurrentFrame unmaskBytes:(BOOL)unmaskBytes
{
    [self assertOnWorkQueue];
    assert(dataLength);

    [_consumers addObject:[_consumerPool consumerWithScanner:nil handler:callback bytesNeeded:dataLength readToCurrentFrame:readToCurrentFrame unmaskBytes:unmaskBytes]];
    [self _pumpScanner];
}

- (void)_addConsumerWithScanner:(stream_scanner)consumer callback:(data_callback)callback dataLength:(size_t)dataLength
{
    [self assertOnWorkQueue];
    [_consumers addObject:[_consumerPool consumerWithScanner:consumer handler:callback bytesNeeded:dataLength readToCurrentFrame:NO unmaskBytes:NO]];
    [self _pumpScanner];
}


- (void)_scheduleCleanup
{
    @synchronized(self) {
        if (_cleanupScheduled) {
            return;
        }

        _cleanupScheduled = YES;

        // Cleanup NSStream delegate's in the same RunLoop used by the streams themselves:
        // This way we'll prevent race conditions between handleEvent and SRWebsocket's dealloc
        NSTimer *timer = [NSTimer timerWithTimeInterval:(0.0f) target:self selector:@selector(_cleanupSelfReference:) userInfo:nil repeats:NO];
        [[NSRunLoop SR_networkRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    }
}

- (void)_cleanupSelfReference:(NSTimer *)timer
{
    @synchronized(self) {
        // Nuke NSStream delegate's
        _inputStream.delegate = nil;
        _outputStream.delegate = nil;

        // Remove the streams, right now, from the networkRunLoop
        [_inputStream close];
        [_outputStream close];
    }

    // Cleanup selfRetain in the same GCD queue as usual
    dispatch_async(_workQueue, ^{
        self->_selfRetain = nil;
    });
}


static const char CRLFCRLFBytes[] = {'\r', '\n', '\r', '\n'};

- (void)_readUntilHeaderCompleteWithCallback:(data_callback)dataHandler
{
    [self _readUntilBytes:CRLFCRLFBytes length:sizeof(CRLFCRLFBytes) callback:dataHandler];
}

- (void)_readUntilBytes:(const void *)bytes length:(size_t)length callback:(data_callback)dataHandler
{
    // TODO optimize so this can continue from where we last searched
    stream_scanner consumer = ^size_t(NSData *data) {
        __block size_t found_size = 0;
        __block size_t match_count = 0;

        size_t size = data.length;
        const unsigned char *buffer = data.bytes;
        for (size_t i = 0; i < size; i++ ) {
            if (((const unsigned char *)buffer)[i] == ((const unsigned char *)bytes)[match_count]) {
                match_count += 1;
                if (match_count == length) {
                    found_size = i + 1;
                    break;
                }
            } else {
                match_count = 0;
            }
        }
        return found_size;
    };
    [self _addConsumerWithScanner:consumer callback:dataHandler];
}


// Returns true if did work
- (BOOL)_innerPumpScanner {

    BOOL didWork = NO;

    if (self.readyState >= SR_CLOSED) {
        return didWork;
    }

    size_t readBufferSize = dispatch_data_get_size(_readBuffer);

    if (!_consumers.count) {
        return didWork;
    }

    size_t curSize = readBufferSize - _readBufferOffset;
    if (!curSize) {
        return didWork;
    }

    SRIOConsumer *consumer = [_consumers objectAtIndex:0];

    size_t bytesNeeded = consumer.bytesNeeded;

    size_t foundSize = 0;
    if (consumer.consumer) {
        NSData *subdata = (NSData *)dispatch_data_create_subrange(_readBuffer, _readBufferOffset, readBufferSize - _readBufferOffset);
        foundSize = consumer.consumer(subdata);
    } else {
        assert(consumer.bytesNeeded);
        if (curSize >= bytesNeeded) {
            foundSize = bytesNeeded;
        } else if (consumer.readToCurrentFrame) {
            foundSize = curSize;
        }
    }

    if (consumer.readToCurrentFrame || foundSize) {
        dispatch_data_t slice = dispatch_data_create_subrange(_readBuffer, _readBufferOffset, foundSize);

        _readBufferOffset += foundSize;

        if (_readBufferOffset > SRDefaultBufferSize() && _readBufferOffset > readBufferSize / 2) {
            _readBuffer = dispatch_data_create_subrange(_readBuffer, _readBufferOffset, readBufferSize - _readBufferOffset);
            _readBufferOffset = 0;
        }

        if (consumer.unmaskBytes) {
            __block NSMutableData *mutableSlice = [slice mutableCopy];

            NSUInteger len = mutableSlice.length;
            uint8_t *bytes = mutableSlice.mutableBytes;

            for (NSUInteger i = 0; i < len; i++) {
                bytes[i] = bytes[i] ^ _currentReadMaskKey[_currentReadMaskOffset % sizeof(_currentReadMaskKey)];
                _currentReadMaskOffset += 1;
            }

            slice = dispatch_data_create(bytes, len, nil, ^{
                mutableSlice = nil;
            });
        }

        if (consumer.readToCurrentFrame) {
            dispatch_data_apply(slice, ^bool(dispatch_data_t region, size_t offset, const void *buffer, size_t size) {
                [_currentFrameData appendBytes:buffer length:size];
                return true;
            });

            _readOpCount += 1;

            if (_currentFrameOpcode == SROpCodeTextFrame) {
                // Validate UTF8 stuff.
                size_t currentDataSize = _currentFrameData.length;
                if (_currentFrameOpcode == SROpCodeTextFrame && currentDataSize > 0) {
                    // TODO: Optimize the crap out of this.  Don't really have to copy all the data each time

                    size_t scanSize = currentDataSize - _currentStringScanPosition;

                    NSData *scan_data = [_currentFrameData subdataWithRange:NSMakeRange(_currentStringScanPosition, scanSize)];
                    int32_t valid_utf8_size = validate_dispatch_data_partial_string(scan_data);

                    if (valid_utf8_size == -1) {
                        [self closeWithCode:SRStatusCodeInvalidUTF8 reason:@"Text frames must be valid UTF-8"];
                        dispatch_async(_workQueue, ^{
                            [self closeConnection];
                        });
                        return didWork;
                    } else {
                        _currentStringScanPosition += valid_utf8_size;
                    }
                }

            }

            consumer.bytesNeeded -= foundSize;

            if (consumer.bytesNeeded == 0) {
                [_consumers removeObjectAtIndex:0];
                consumer.handler(self, nil);
                [_consumerPool returnConsumer:consumer];
                didWork = YES;
            }
        } else if (foundSize) {
            [_consumers removeObjectAtIndex:0];
            consumer.handler(self, (NSData *)slice);
            [_consumerPool returnConsumer:consumer];
            didWork = YES;
        }
    }
    return didWork;
}

-(void)_pumpScanner
{
    [self assertOnWorkQueue];

    if (!_isPumping) {
        _isPumping = YES;
    } else {
        return;
    }

    while ([self _innerPumpScanner]) {

    }

    _isPumping = NO;
}

//#define NOMASK

static const size_t SRFrameHeaderOverhead = 32;

- (void)_sendFrameWithOpcode:(SROpCode)opCode data:(NSData *)data
{
    [self assertOnWorkQueue];

    if (!data) {
        return;
    }

    size_t payloadLength = data.length;

    NSMutableData *frameData = [[NSMutableData alloc] initWithLength:payloadLength + SRFrameHeaderOverhead];
    if (!frameData) {
        [self closeWithCode:SRStatusCodeMessageTooBig reason:@"Message too big"];
        return;
    }
    uint8_t *frameBuffer = (uint8_t *)frameData.mutableBytes;

    // set fin
    frameBuffer[0] = SRFinMask | opCode;

    // set the mask and header
    frameBuffer[1] |= SRMaskMask;

    size_t frameBufferSize = 2;

    if (payloadLength < 126) {
        frameBuffer[1] |= payloadLength;
    } else {
        uint64_t declaredPayloadLength = 0;
        size_t declaredPayloadLengthSize = 0;

        if (payloadLength <= UINT16_MAX) {
            frameBuffer[1] |= 126;

            declaredPayloadLength = CFSwapInt16BigToHost((uint16_t)payloadLength);
            declaredPayloadLengthSize = sizeof(uint16_t);
        } else {
            frameBuffer[1] |= 127;

            declaredPayloadLength = CFSwapInt64BigToHost((uint64_t)payloadLength);
            declaredPayloadLengthSize = sizeof(uint64_t);
        }

        memcpy((frameBuffer + frameBufferSize), &declaredPayloadLength, declaredPayloadLengthSize);
        frameBufferSize += declaredPayloadLengthSize;
    }

    const uint8_t *unmaskedPayloadBuffer = (uint8_t *)data.bytes;
    uint8_t *maskKey = frameBuffer + frameBufferSize;

    size_t randomBytesSize = sizeof(uint32_t);
    NSData *randomData = SRRandomData(randomBytesSize);
    [randomData getBytes:maskKey range:NSMakeRange(0, randomBytesSize)];
    frameBufferSize += randomBytesSize;

    // Copy and unmask the buffer
    uint8_t *frameBufferPayloadPointer = frameBuffer + frameBufferSize;

    memcpy(frameBufferPayloadPointer, unmaskedPayloadBuffer, payloadLength);
    SRMaskBytesSIMD(frameBufferPayloadPointer, payloadLength, maskKey);
    frameBufferSize += payloadLength;

    assert(frameBufferSize <= frameData.length);
    frameData.length = frameBufferSize;

    [self _writeData:frameData];
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    __weak typeof(self) wself = self;

    if (_requestRequiresSSL && !_streamSecurityValidated &&
        (eventCode == NSStreamEventHasBytesAvailable || eventCode == NSStreamEventHasSpaceAvailable)) {
        SecTrustRef trust = (__bridge SecTrustRef)[aStream propertyForKey:(__bridge id)kCFStreamPropertySSLPeerTrust];
        if (trust) {
            NSString *const host = _urlRequest.URL.host;
            if (!host || host.length == 0) {
                dispatch_async(_workQueue, ^{
                    NSError *error = SRErrorWithDomainCodeDescription(NSURLErrorDomain,
                                                                      NSURLErrorBadURL,
                                                                      @"Unable to validate certificate for empty host.");
                    [wself _failWithError:error];
                });
                return;
            }
            _streamSecurityValidated = [_securityPolicy evaluateServerTrust:trust forDomain:host];
        }
        if (!_streamSecurityValidated) {
            dispatch_async(_workQueue, ^{
                NSError *error = SRErrorWithDomainCodeDescription(NSURLErrorDomain,
                                                                  NSURLErrorClientCertificateRejected,
                                                                  @"Invalid server certificate.");
                [wself _failWithError:error];
            });
            return;
        }
        dispatch_async(_workQueue, ^{
            [self didConnect];
        });
    }
    dispatch_async(_workQueue, ^{
        [wself safeHandleEvent:eventCode stream:aStream];
    });
}

- (void)safeHandleEvent:(NSStreamEvent)eventCode stream:(NSStream *)aStream
{
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            SRDebugLog(@"NSStreamEventOpenCompleted %@", aStream);
            if (self.readyState >= SR_CLOSING) {
                return;
            }
            assert(_readBuffer);

            if (!_requestRequiresSSL && self.readyState == SR_CONNECTING && aStream == _inputStream) {
                [self didConnect];
            }

            [self _pumpWriting];
            [self _pumpScanner];

            break;
        }

        case NSStreamEventErrorOccurred: {
            SRDebugLog(@"NSStreamEventErrorOccurred %@ %@", aStream, [[aStream streamError] copy]);
            /// TODO specify error better!
            [self _failWithError:aStream.streamError];
            _readBufferOffset = 0;
            _readBuffer = dispatch_data_empty;
            break;

        }

        case NSStreamEventEndEncountered: {
            [self _pumpScanner];
            SRDebugLog(@"NSStreamEventEndEncountered %@", aStream);
            if (aStream.streamError) {
                [self _failWithError:aStream.streamError];
            } else {
                dispatch_async(_workQueue, ^{
                    if (self.readyState != SR_CLOSED) {
                        self.readyState = SR_CLOSED;
                        [self _scheduleCleanup];
                    }

                    if (!self->_sentClose && !self->_failed) {
                        self->_sentClose = YES;
                        // If we get closed in this state it's probably not clean because we should be sending this when we send messages
                        [self.delegateController performDelegateBlock:^(id<SRWebSocketDelegate>  _Nullable delegate, SRDelegateAvailableMethods availableMethods) {
                            if (availableMethods.didCloseWithCode) {
                                [delegate webSocket:self
                                   didCloseWithCode:SRStatusCodeGoingAway
                                             reason:@"Stream end encountered"
                                           wasClean:NO];
                            }
                        }];
                    }
                });
            }

            break;
        }

        case NSStreamEventHasBytesAvailable: {
            SRDebugLog(@"NSStreamEventHasBytesAvailable %@", aStream);
            uint8_t buffer[SRDefaultBufferSize()];

            while (_inputStream.hasBytesAvailable) {
                NSInteger bytesRead = [_inputStream read:buffer maxLength:SRDefaultBufferSize()];
                if (bytesRead > 0) {
                    dispatch_data_t data = dispatch_data_create(buffer, bytesRead, nil, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
                    if (!data) {
                        NSError *error = SRErrorWithCodeDescription(SRStatusCodeMessageTooBig,
                                                                    @"Unable to allocate memory to read from socket.");
                        [self _failWithError:error];
                        return;
                    }
                    _readBuffer = dispatch_data_create_concat(_readBuffer, data);
                } else if (bytesRead == -1) {
                    [self _failWithError:_inputStream.streamError];
                }
            }
            [self _pumpScanner];
            break;
        }

        case NSStreamEventHasSpaceAvailable: {
            SRDebugLog(@"NSStreamEventHasSpaceAvailable %@", aStream);
            [self _pumpWriting];
            break;
        }

        case NSStreamEventNone:
            SRDebugLog(@"(default)  %@", aStream);
            break;
    }
}

///--------------------------------------
#pragma mark - Delegate
///--------------------------------------

- (id<SRWebSocketDelegate> _Nullable)delegate
{
    return self.delegateController.delegate;
}

- (void)setDelegate:(id<SRWebSocketDelegate> _Nullable)delegate
{
    self.delegateController.delegate = delegate;
}

- (void)setDelegateDispatchQueue:(dispatch_queue_t _Nullable)queue
{
    self.delegateController.dispatchQueue = queue;
}

- (dispatch_queue_t _Nullable)delegateDispatchQueue
{
    return self.delegateController.dispatchQueue;
}

- (void)setDelegateOperationQueue:(NSOperationQueue *_Nullable)queue
{
    self.delegateController.operationQueue = queue;
}

- (NSOperationQueue *_Nullable)delegateOperationQueue
{
    return self.delegateController.operationQueue;
}

@end

#ifdef HAS_ICU

static inline int32_t validate_dispatch_data_partial_string(NSData *data) {
    if ([data length] > INT32_MAX) {
        // INT32_MAX is the limit so long as this Framework is using 32 bit ints everywhere.
        return -1;
    }

    int32_t size = (int32_t)[data length];

    const void * contents = [data bytes];
    const uint8_t *str = (const uint8_t *)contents;

    UChar32 codepoint = 1;
    int32_t offset = 0;
    int32_t lastOffset = 0;
    while(offset < size && codepoint > 0)  {
        lastOffset = offset;
        U8_NEXT(str, offset, size, codepoint);
    }

    if (codepoint == -1) {
        // Check to see if the last byte is valid or whether it was just continuing
        if (!U8_IS_LEAD(str[lastOffset]) || U8_COUNT_TRAIL_BYTES(str[lastOffset]) + lastOffset < (int32_t)size) {

            size = -1;
        } else {
            uint8_t leadByte = str[lastOffset];
            U8_MASK_LEAD_BYTE(leadByte, U8_COUNT_TRAIL_BYTES(leadByte));

            for (int i = lastOffset + 1; i < offset; i++) {
                if (U8_IS_SINGLE(str[i]) || U8_IS_LEAD(str[i]) || !U8_IS_TRAIL(str[i])) {
                    size = -1;
                }
            }

            if (size != -1) {
                size = lastOffset;
            }
        }
    }

    if (size != -1 && ![[NSString alloc] initWithBytesNoCopy:(char *)[data bytes] length:size encoding:NSUTF8StringEncoding freeWhenDone:NO]) {
        size = -1;
    }

    return size;
}

#else

// This is a hack, and probably not optimal
static inline int32_t validate_dispatch_data_partial_string(NSData *data) {
    static const int maxCodepointSize = 3;

    for (int i = 0; i < maxCodepointSize; i++) {
        NSString *str = [[NSString alloc] initWithBytesNoCopy:(char *)data.bytes length:data.length - i encoding:NSUTF8StringEncoding freeWhenDone:NO];
        if (str) {
            return (int32_t)data.length - i;
        }
    }

    return -1;
}

#endif
