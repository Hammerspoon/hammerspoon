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

#import "PSWebSocket.h"
#import "PSWebSocketInternal.h"
#import "PSWebSocketDriver.h"
#import "PSWebSocketBuffer.h"
#import <sys/socket.h>
#import <arpa/inet.h>


@interface PSWebSocket() <NSStreamDelegate, PSWebSocketDriverDelegate> {
    PSWebSocketMode _mode;
    NSMutableURLRequest *_request;
    dispatch_queue_t _workQueue;
    PSWebSocketDriver *_driver;
    PSWebSocketBuffer *_inputBuffer;
    PSWebSocketBuffer *_outputBuffer;
    NSInputStream *_inputStream;
    NSOutputStream *_outputStream;
    PSWebSocketReadyState _readyState;
    BOOL _secure;
    BOOL _negotiatedSSL;
    BOOL _opened;
    BOOL _closeWhenFinishedOutput;
    BOOL _sentClose;
    BOOL _failed;
    BOOL _pumpingInput;
    BOOL _pumpingOutput;
    BOOL _inputPaused;
    BOOL _outputPaused;
    NSInteger _closeCode;
    NSString *_closeReason;
    NSMutableArray *_pingHandlers;
}
@end
@implementation PSWebSocket

#pragma mark - Class Methods

+ (BOOL)isWebSocketRequest:(NSURLRequest *)request {
    return [PSWebSocketDriver isWebSocketRequest:request];
}

#pragma mark - Properties

- (PSWebSocketReadyState)readyState {
    __block PSWebSocketReadyState value = 0;
    [self executeWorkAndWait:^{
        value = _readyState;
    }];
    return value;
}

- (NSData* )remoteAddress {
    return PSPeerAddressOfInputStream(_inputStream);
}

- (NSString* )remoteHost {
    return PSPeerHostOfInputStream(_inputStream);
}

@synthesize inputPaused = _inputPaused, outputPaused = _outputPaused;

- (BOOL)isInputPaused {
    __block BOOL result;
    [self executeWorkAndWait:^{
        result = _inputPaused;
    }];
    return result;
}
- (void)setInputPaused:(BOOL)inputPaused {
    [self executeWorkAndWait:^{
        if (inputPaused != _inputPaused) {
            _inputPaused = inputPaused;
            if (!inputPaused) {
                [self pumpInput];
            }
        }
    }];
}

- (BOOL)isOutputPaused {
    __block BOOL result;
    [self executeWorkAndWait:^{
        result = _outputPaused;
    }];
    return result;
}
- (void)setOutputPaused:(BOOL)outputPaused {
    [self executeWorkAndWait:^{
        if (outputPaused != _outputPaused) {
            _outputPaused = outputPaused;
            if (!outputPaused) {
                [self pumpOutput];
            }
        }
    }];
}

#pragma mark - Initialization

- (instancetype)initWithMode:(PSWebSocketMode)mode request:(NSURLRequest *)request {
	if((self = [super init])) {
        _mode = mode;
        _request = [request mutableCopy];
		_readyState = PSWebSocketReadyStateConnecting;
        NSString* name = [NSString stringWithFormat: @"PSWebSocket <%@>", request.URL];
        _workQueue = dispatch_queue_create(name.UTF8String, nil);
        if(_mode == PSWebSocketModeClient) {
            _driver = [PSWebSocketDriver clientDriverWithRequest:_request];
        } else {
            _driver = [PSWebSocketDriver serverDriverWithRequest:_request];
        }
        _driver.delegate = self;
        _secure = ([_request.URL.scheme hasPrefix:@"https"] || [_request.URL.scheme hasPrefix:@"wss"]);
        _negotiatedSSL = YES;
        _opened = NO;
        _closeWhenFinishedOutput = NO;
        _sentClose = NO;
        _failed = NO;
        _pumpingInput = NO;
        _pumpingOutput = NO;
        _closeCode = 0;
        _closeReason = nil;
        _pingHandlers = [NSMutableArray array];
        _inputBuffer = [[PSWebSocketBuffer alloc] init];
        _outputBuffer = [[PSWebSocketBuffer alloc] init];
        if(_request.HTTPBody.length > 0) {
            [_inputBuffer appendData:_request.HTTPBody];
            _request.HTTPBody = nil;
        }
	}
	return self;
}

+ (instancetype)clientSocketWithRequest:(NSURLRequest *)request {
    return [[self alloc] initClientSocketWithRequest:request];
}
- (instancetype)initClientSocketWithRequest:(NSURLRequest *)request {
	if((self = [self initWithMode:PSWebSocketModeClient request:request])) {
        NSURL *URL = request.URL;
        NSString *host = URL.host;
        UInt32 port = (UInt32)request.URL.port.integerValue;
        if(port == 0) {
            port = (_secure) ? 443 : 80;
        }
        
        CFReadStreamRef readStream = nil;
        CFWriteStreamRef writeStream = nil;
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                           (__bridge CFStringRef)host,
                                           port,
                                           &readStream,
                                           &writeStream);
        NSAssert(readStream && writeStream, @"Failed to create streams for client socket");
        
        _inputStream = CFBridgingRelease(readStream);
        _outputStream = CFBridgingRelease(writeStream);
    }
	return self;
}

+ (instancetype)serverSocketWithRequest:(NSURLRequest *)request inputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream {
    return [[self alloc] initServerWithRequest:request inputStream:inputStream outputStream:outputStream];
}
- (instancetype)initServerWithRequest:(NSURLRequest *)request inputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream {
    if((self = [self initWithMode:PSWebSocketModeServer request:request])) {
        _inputStream = inputStream;
        _outputStream = outputStream;
    }
    return self;
}

#pragma mark - Actions

- (void)open {
    [self executeWork:^{
        if(_opened || _readyState != PSWebSocketReadyStateConnecting) {
            [NSException raise:@"Invalid State" format:@"You cannot open a PSWebSocket more than once."];
            return;
        }
        
        _opened = YES;
        
        // connect
        [self connect];
    }];
}
- (void)send:(id)message {
    NSParameterAssert(message);
    [self executeWork:^{
        if([message isKindOfClass:[NSString class]]) {
            [_driver sendText:message];
        } else if([message isKindOfClass:[NSData class]]) {
            [_driver sendBinary:message];
        } else {
            [NSException raise:@"Invalid Message" format:@"Messages must be instances of NSString or NSData"];
        }
    }];
}
- (void)ping:(NSData *)pingData handler:(void (^)(NSData *pongData))handler {
    [self executeWork:^{
        if(handler) {
            [_pingHandlers addObject:handler];
        }
        [_driver sendPing:pingData];
    }];
}
- (void)close {
    [self closeWithCode:1000 reason:nil];
}
- (void)closeWithCode:(NSInteger)code reason:(NSString *)reason {
    [self executeWork:^{
        // already closing so lets exit
        if(_readyState >= PSWebSocketReadyStateClosing) {
            return;
        }
        
        BOOL connecting = (_readyState == PSWebSocketReadyStateConnecting);
        _readyState = PSWebSocketReadyStateClosing;
        
        // send close code if we're not connecting
        if(!connecting) {
            _closeCode = code;
            [_driver sendCloseCode:code reason:reason];
        }
        
        // disconnect gracefully
        [self disconnectGracefully];
        
        // disconnect hard in 30 seconds
        __weak typeof(self)weakSelf = self;
        dispatch_after(dispatch_walltime(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf)strongSelf = weakSelf;
            if(!strongSelf) return;
            
            [strongSelf executeWork:^{
                if(strongSelf->_readyState >= PSWebSocketReadyStateClosed) {
                    return;
                }
                [strongSelf disconnect];
            }];
        });
    }];
}

#pragma mark - Stream Properties

- (CFTypeRef)copyStreamPropertyForKey:(NSString *)key {
    __block CFTypeRef result;
    [self executeWorkAndWait:^{
        result = CFWriteStreamCopyProperty((__bridge CFWriteStreamRef)_outputStream, (__bridge CFStringRef)key);
    }];
    return result;
}
- (void)setStreamProperty:(CFTypeRef)property forKey:(NSString *)key {
    [self executeWorkAndWait:^{
        if(_opened || _readyState != PSWebSocketReadyStateConnecting) {
            [NSException raise:@"Invalid State" format:@"You cannot set stream properties on a PSWebSocket once it is opened."];
            return;
        }
        CFWriteStreamSetProperty((__bridge CFWriteStreamRef)_outputStream, (__bridge CFStringRef)key, (CFTypeRef)property);
    }];
}

#pragma mark - Connection

- (void)connect {
    if(_secure && _mode == PSWebSocketModeClient) {
        
        __block BOOL customTrustEvaluation = NO;
        [self executeDelegateAndWait:^{
            customTrustEvaluation = [_delegate respondsToSelector:@selector(webSocket:evaluateServerTrust:)];
        }];
        
        NSMutableDictionary *ssl = [NSMutableDictionary dictionary];
        ssl[(__bridge id)kCFStreamSSLLevel] = (__bridge id)kCFStreamSocketSecurityLevelNegotiatedSSL;
        ssl[(__bridge id)kCFStreamSSLValidatesCertificateChain] = @(!customTrustEvaluation);
        ssl[(__bridge id)kCFStreamSSLIsServer] = @NO;
        
        _negotiatedSSL = !customTrustEvaluation;
        [_inputStream setProperty:ssl forKey:(__bridge id)kCFStreamPropertySSLSettings];
    }

    // delegate
    _inputStream.delegate = self;
    _outputStream.delegate = self;
    
    // driver
    [_driver start];
    
    // schedule streams
    CFReadStreamSetDispatchQueue((__bridge CFReadStreamRef)_inputStream, _workQueue);
    CFWriteStreamSetDispatchQueue((__bridge CFWriteStreamRef)_outputStream, _workQueue);

    // open streams
    if(_inputStream.streamStatus == NSStreamStatusNotOpen) {
        [_inputStream open];
    }
    if(_outputStream.streamStatus == NSStreamStatusNotOpen) {
        [_outputStream open];
    }
    
    // pump
    [self pumpInput];
    [self pumpOutput];
    
    // prepare timeout
    if(_request.timeoutInterval > 0.0) {
        __weak typeof(self)weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_request.timeoutInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf)strongSelf = weakSelf;
            if(strongSelf) {
                [strongSelf executeWork:^{
                    if(strongSelf->_readyState == PSWebSocketReadyStateConnecting) {
                        [strongSelf failWithCode:PSWebSocketErrorCodeTimedOut reason:@"Timed out."];
                    }
                }];
            }
        });
    }
}
- (void)disconnectGracefully {
    _closeWhenFinishedOutput = YES;
    [self pumpOutput];
}
- (void)disconnect {
    _inputStream.delegate = nil;
    _outputStream.delegate = nil;
    
    [_inputStream close];
    [_outputStream close];
    
    _inputStream = nil;
    _outputStream = nil;
}

#pragma mark - SSL

- (void)negotiateSSL:(NSStream *)stream {
    if (_negotiatedSSL) {
        return;
    }
    
    SecTrustRef trust = (__bridge SecTrustRef)[stream propertyForKey:(__bridge id)kCFStreamPropertySSLPeerTrust];
    BOOL accept = [self askDelegateToEvaluateServerTrust:trust];
    if(accept) {
        _negotiatedSSL = YES;
        [self pumpOutput];
        [self pumpInput];
    } else {
        _negotiatedSSL = NO;
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                             code:NSURLErrorServerCertificateUntrusted
                                         userInfo:@{NSURLErrorFailingURLErrorKey: _request.URL}];
        [self failWithError:error];
    }
}

#pragma mark - Pumping

- (void)pumpInput {
    if(_readyState >= PSWebSocketReadyStateClosing ||
       _pumpingInput ||
       _inputPaused ||
       !_inputStream.hasBytesAvailable) {
        return;
    }

    _pumpingInput = YES;
    @autoreleasepool {
        uint8_t chunkBuffer[4096];
        NSInteger readLength = [_inputStream read:chunkBuffer maxLength:sizeof(chunkBuffer)];
        if(readLength > 0) {
            if(!_inputBuffer.hasBytesAvailable) {
                NSInteger consumedLength = [_driver execute:chunkBuffer maxLength:readLength];
                if(consumedLength < readLength) {
                    NSInteger offset = MAX(0, consumedLength);
                    NSInteger remaining = readLength - offset;
                    [_inputBuffer appendBytes:chunkBuffer + offset length:remaining];
                }
            } else {
                [_inputBuffer appendBytes:chunkBuffer length:readLength];
            }
        } else if(readLength < 0) {
            [self failWithError:_inputStream.streamError];
        }

        while(_inputBuffer.hasBytesAvailable) {
            NSInteger readLength = [_driver execute:_inputBuffer.mutableBytes maxLength:_inputBuffer.bytesAvailable];
            if(readLength <= 0) {
                break;
            }
            _inputBuffer.offset += readLength;
        }

        [_inputBuffer compact];
        
        if(_readyState == PSWebSocketReadyStateOpen &&
           !_inputStream.hasBytesAvailable &&
           !_inputBuffer.hasBytesAvailable) {
            [self notifyDelegateDidFlushInput];
        }
    }
    _pumpingInput = NO;
}

- (void)pumpOutput {
    if(_pumpingInput ||
       _outputPaused) {
        return;
    }
    
    _pumpingOutput = YES;
    do {
        while(_outputStream.hasSpaceAvailable && _outputBuffer.hasBytesAvailable) {
            NSInteger writeLength = [_outputStream write:_outputBuffer.bytes maxLength:_outputBuffer.bytesAvailable];
            if(writeLength <= -1) {
                _failed = YES;
                [self disconnect];
                NSString *reason = @"Failed to write to output stream";
                NSError *error = [PSWebSocketDriver errorWithCode:PSWebSocketErrorCodeConnectionFailed reason:reason];
                [self notifyDelegateDidFailWithError:error];
                return;
            }
            _outputBuffer.offset += writeLength;
        }
        if(_closeWhenFinishedOutput &&
           !_outputBuffer.hasBytesAvailable &&
           (_inputStream.streamStatus != NSStreamStatusNotOpen &&
            _inputStream.streamStatus != NSStreamStatusClosed) &&
           !_sentClose) {
            _sentClose = YES;
            
            [self disconnect];
            
            if(!_failed) {
                [self notifyDelegateDidCloseWithCode:_closeCode reason:_closeReason wasClean:YES];
            }
        }
        
        [_outputBuffer compact];

        if(_readyState == PSWebSocketReadyStateOpen &&
           _outputStream.hasSpaceAvailable &&
           !_outputBuffer.hasBytesAvailable) {
            [self notifyDelegateDidFlushOutput];
        }
        
    } while (_outputStream.hasSpaceAvailable && _outputBuffer.hasBytesAvailable);
    _pumpingOutput = NO;
}

#pragma mark - Failing

- (void)failWithCode:(NSInteger)code reason:(NSString *)reason {
    [self failWithError:[PSWebSocketDriver errorWithCode:code reason:reason]];
}
- (void)failWithError:(NSError *)error {
    if(error.code == PSWebSocketStatusCodeProtocolError && [error.domain isEqualToString:PSWebSocketErrorDomain]) {
        [self executeDelegate:^{
            _closeCode = error.code;
            _closeReason = error.localizedDescription;
            [self closeWithCode:_closeCode reason:_closeReason];
            [self executeWork:^{
                [self disconnectGracefully];
            }];
        }];
    } else {
        [self executeWork:^{
            if(_readyState != PSWebSocketReadyStateClosed) {
                _failed = YES;
                _readyState = PSWebSocketReadyStateClosed;
                [self notifyDelegateDidFailWithError:error];
                [self disconnectGracefully];
            }
        }];
    }
}

#pragma mark - PSWebSocketDriverDelegate

- (void)driverDidOpen:(PSWebSocketDriver *)driver {
    if(_readyState != PSWebSocketReadyStateConnecting) {
        [NSException raise:@"Invalid State" format:@"Ready state must be connecting to become open"];
        return;
    }
    _readyState = PSWebSocketReadyStateOpen;
    [self notifyDelegateDidOpen];
    [self pumpInput];
    [self pumpOutput];
}
- (void)driver:(PSWebSocketDriver *)driver didFailWithError:(NSError *)error {
    [self failWithError:error];
}
- (void)driver:(PSWebSocketDriver *)driver didCloseWithCode:(NSInteger)code reason:(NSString *)reason {
    _closeCode = code;
    _closeReason = reason;
    if(_readyState == PSWebSocketReadyStateOpen) {
        [self closeWithCode:1000 reason:nil];
    }
    [self executeWork:^{
        [self disconnectGracefully];
    }];
}
- (void)driver:(PSWebSocketDriver *)driver didReceiveMessage:(id)message {
    [self notifyDelegateDidReceiveMessage:message];
}
- (void)driver:(PSWebSocketDriver *)driver didReceivePing:(NSData *)ping {
    [self executeDelegate:^{
        [self executeWork:^{
            [driver sendPong:ping];
        }];
    }];
}
- (void)driver:(PSWebSocketDriver *)driver didReceivePong:(NSData *)pong {
    void (^handler)(NSData *pong) = [_pingHandlers firstObject];
    if(handler) {
        [self executeDelegate:^{
            handler(pong);
        }];
        [_pingHandlers removeObjectAtIndex:0];
    }
}
- (void)driver:(PSWebSocketDriver *)driver write:(NSData *)data {
    if(_closeWhenFinishedOutput) {
        return;
    }
    [_outputBuffer appendData:data];
    [self pumpOutput];
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)event {
    // This is invoked on the work queue.
    switch(event) {
        case NSStreamEventOpenCompleted: {
            if(_mode != PSWebSocketModeClient) {
                [NSException raise:@"Invalid State" format:@"Server mode should have already opened streams."];
                return;
            }
            if(_readyState >= PSWebSocketReadyStateClosing) {
                return;
            }
            [self pumpOutput];
            [self pumpInput];
            break;
        }
        case NSStreamEventErrorOccurred: {
            [self failWithError:stream.streamError];
            [_inputBuffer reset];
            break;
        }
        case NSStreamEventEndEncountered: {
            [self pumpInput];
            if(stream.streamError) {
                [self failWithError:stream.streamError];
            } else {
                _readyState = PSWebSocketReadyStateClosed;
                if(!_sentClose && !_failed) {
                    _failed = YES;
                    [self disconnect];
                    NSString *reason = [NSString stringWithFormat:@"%@ stream end encountered", (stream == _inputStream) ? @"Input" : @"Output"];
                    NSError *error = [PSWebSocketDriver errorWithCode:PSWebSocketErrorCodeConnectionFailed reason:reason];
                    [self notifyDelegateDidFailWithError:error];
                }
            }
            break;
        }
        case NSStreamEventHasBytesAvailable: {
            if (!_negotiatedSSL) {
                [self negotiateSSL:stream];
            } else {
                [self pumpInput];
            }
            break;
        }
        case NSStreamEventHasSpaceAvailable: {
            if (!_negotiatedSSL) {
                [self negotiateSSL:stream];
            } else {
                [self pumpOutput];
            }
            break;
        }
        default:
            break;
    }
}

#pragma mark - Delegation

- (void)notifyDelegateDidOpen {
    [self executeDelegate:^{
        [_delegate webSocketDidOpen:self];
    }];
}
- (void)notifyDelegateDidReceiveMessage:(id)message {
    [self executeDelegate:^{
        [_delegate webSocket:self didReceiveMessage:message];
    }];
}
- (void)notifyDelegateDidFailWithError:(NSError *)error {
    [self executeDelegate:^{
        [_delegate webSocket:self didFailWithError:error];
    }];
}
- (void)notifyDelegateDidCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    [self executeDelegate:^{
        [_delegate webSocket:self didCloseWithCode:code reason:reason wasClean:wasClean];
    }];
}
- (void)notifyDelegateDidFlushInput {
    [self executeDelegate:^{
        if ([_delegate respondsToSelector:@selector(webSocketDidFlushInput:)]) {
            [_delegate webSocketDidFlushInput:self];
        }
    }];
}
- (void)notifyDelegateDidFlushOutput {
    [self executeDelegate:^{
        if ([_delegate respondsToSelector:@selector(webSocketDidFlushOutput:)]) {
            [_delegate webSocketDidFlushOutput:self];
        }
    }];
}
- (BOOL)askDelegateToEvaluateServerTrust:(SecTrustRef)trust {
    __block BOOL result = NO;
    [self executeDelegateAndWait:^{
        if ([_delegate respondsToSelector:@selector(webSocket:evaluateServerTrust:)]) {
            result = [_delegate webSocket:self evaluateServerTrust:trust];
        }
    }];
    return result;
}

#pragma mark - Queueing

- (void)executeWork:(void (^)(void))work {
    NSParameterAssert(work);
    dispatch_async(_workQueue, work);
}
- (void)executeWorkAndWait:(void (^)(void))work {
    NSParameterAssert(work);
    dispatch_sync(_workQueue, work);
}
- (void)executeDelegate:(void (^)(void))work {
    NSParameterAssert(work);
    dispatch_async((_delegateQueue) ? _delegateQueue : dispatch_get_main_queue(), work);
}
- (void)executeDelegateAndWait:(void (^)(void))work {
    NSParameterAssert(work);
    dispatch_sync((_delegateQueue) ? _delegateQueue : dispatch_get_main_queue(), work);
}

#pragma mark - Dealloc

- (void)dealloc {
    [self disconnect];
}

@end
