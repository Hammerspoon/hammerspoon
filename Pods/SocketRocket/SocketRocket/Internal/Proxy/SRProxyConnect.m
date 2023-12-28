//
// Copyright (c) 2016-present, Facebook, Inc.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree. An additional grant
// of patent rights can be found in the PATENTS file in the same directory.
//

#import "SRProxyConnect.h"

#import "NSRunLoop+SRWebSocket.h"
#import "SRConstants.h"
#import "SRError.h"
#import "SRLog.h"
#import "SRURLUtilities.h"

@interface SRProxyConnect() <NSStreamDelegate>

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSOutputStream *outputStream;

@end

@implementation SRProxyConnect
{
    SRProxyConnectCompletion _completion;

    NSString *_httpProxyHost;
    uint32_t _httpProxyPort;

    CFHTTPMessageRef _receivedHTTPHeaders;

    NSString *_socksProxyHost;
    uint32_t _socksProxyPort;
    NSString *_socksProxyUsername;
    NSString *_socksProxyPassword;

    BOOL _connectionRequiresSSL;

    NSMutableArray<NSData *> *_inputQueue;
    dispatch_queue_t _writeQueue;
}

///--------------------------------------
#pragma mark - Init
///--------------------------------------

-(instancetype)initWithURL:(NSURL *)url
{
    self = [super init];
    if (!self) return self;

    _url = url;
    _connectionRequiresSSL = SRURLRequiresSSL(url);

    _writeQueue = dispatch_queue_create("com.facebook.socketrocket.proxyconnect.write", DISPATCH_QUEUE_SERIAL);
    _inputQueue = [NSMutableArray arrayWithCapacity:2];

    return self;
}

- (void)dealloc
{
    // If we get deallocated before the socket open finishes - we need to cleanup everything.

    [self.inputStream removeFromRunLoop:[NSRunLoop SR_networkRunLoop] forMode:NSDefaultRunLoopMode];
    self.inputStream.delegate = nil;
    [self.inputStream close];
    self.inputStream = nil;

    self.outputStream.delegate = nil;
    [self.outputStream close];
    self.outputStream = nil;
}

///--------------------------------------
#pragma mark - Open
///--------------------------------------

- (void)openNetworkStreamWithCompletion:(SRProxyConnectCompletion)completion
{
    _completion = completion;
    [self _configureProxy];
}

///--------------------------------------
#pragma mark - Flow
///--------------------------------------

- (void)_didConnect
{
    SRDebugLog(@"_didConnect, return streams");
    if (_connectionRequiresSSL) {
        if (_httpProxyHost) {
            // Must set the real peer name before turning on SSL
            SRDebugLog(@"proxy set peer name to real host %@", self.url.host);
            [self.outputStream setProperty:self.url.host forKey:@"_kCFStreamPropertySocketPeerName"];
        }
    }
    if (_receivedHTTPHeaders) {
        CFRelease(_receivedHTTPHeaders);
        _receivedHTTPHeaders = NULL;
    }

    NSInputStream *inputStream = self.inputStream;
    NSOutputStream *outputStream = self.outputStream;

    self.inputStream = nil;
    self.outputStream = nil;

    [inputStream removeFromRunLoop:[NSRunLoop SR_networkRunLoop] forMode:NSDefaultRunLoopMode];
    inputStream.delegate = nil;
    outputStream.delegate = nil;

    _completion(nil, inputStream, outputStream);
}

- (void)_failWithError:(NSError *)error
{
    SRDebugLog(@"_failWithError, return error");
    if (!error) {
        error = SRHTTPErrorWithCodeDescription(500, 2132,@"Proxy Error");
    }

    if (_receivedHTTPHeaders) {
        CFRelease(_receivedHTTPHeaders);
        _receivedHTTPHeaders = NULL;
    }

    self.inputStream.delegate = nil;
    self.outputStream.delegate = nil;

    [self.inputStream removeFromRunLoop:[NSRunLoop SR_networkRunLoop]
                                forMode:NSDefaultRunLoopMode];
    [self.inputStream close];
    [self.outputStream close];
    self.inputStream = nil;
    self.outputStream = nil;
    _completion(error, nil, nil);
}

// get proxy setting from device setting
- (void)_configureProxy
{
    SRDebugLog(@"configureProxy");
    NSDictionary *proxySettings = CFBridgingRelease(CFNetworkCopySystemProxySettings());

    // CFNetworkCopyProxiesForURL doesn't understand ws:// or wss://
    NSURL *httpURL;
    if (_connectionRequiresSSL) {
        httpURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@", _url.host]];
    } else {
        httpURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", _url.host]];
    }

    NSArray *proxies = CFBridgingRelease(CFNetworkCopyProxiesForURL((__bridge CFURLRef)httpURL, (__bridge CFDictionaryRef)proxySettings));
    if (proxies.count == 0) {
        SRDebugLog(@"configureProxy no proxies");
        [self _openConnection];
        return;                 // no proxy
    }
    NSDictionary *settings = [proxies objectAtIndex:0];
    NSString *proxyType = settings[(NSString *)kCFProxyTypeKey];
    if ([proxyType isEqualToString:(NSString *)kCFProxyTypeAutoConfigurationURL]) {
        NSURL *pacURL = settings[(NSString *)kCFProxyAutoConfigurationURLKey];
        if (pacURL) {
            [self _fetchPAC:pacURL withProxySettings:proxySettings];
            return;
        }
    }
    if ([proxyType isEqualToString:(__bridge NSString *)kCFProxyTypeAutoConfigurationJavaScript]) {
        NSString *script = settings[(__bridge NSString *)kCFProxyAutoConfigurationJavaScriptKey];
        if (script) {
            [self _runPACScript:script withProxySettings:proxySettings];
            return;
        }
    }
    [self _readProxySettingWithType:proxyType settings:settings];

    [self _openConnection];
}

- (void)_readProxySettingWithType:(NSString *)proxyType settings:(NSDictionary *)settings
{
    if ([proxyType isEqualToString:(NSString *)kCFProxyTypeHTTP] ||
        [proxyType isEqualToString:(NSString *)kCFProxyTypeHTTPS]) {
        _httpProxyHost = settings[(NSString *)kCFProxyHostNameKey];
        NSNumber *portValue = settings[(NSString *)kCFProxyPortNumberKey];
        if (portValue) {
            _httpProxyPort = [portValue intValue];
        }
    }
    if ([proxyType isEqualToString:(NSString *)kCFProxyTypeSOCKS]) {
        _socksProxyHost = settings[(NSString *)kCFProxyHostNameKey];
        NSNumber *portValue = settings[(NSString *)kCFProxyPortNumberKey];
        if (portValue)
            _socksProxyPort = [portValue intValue];
        _socksProxyUsername = settings[(NSString *)kCFProxyUsernameKey];
        _socksProxyPassword = settings[(NSString *)kCFProxyPasswordKey];
    }
    if (_httpProxyHost) {
        SRDebugLog(@"Using http proxy %@:%u", _httpProxyHost, _httpProxyPort);
    } else if (_socksProxyHost) {
        SRDebugLog(@"Using socks proxy %@:%u", _socksProxyHost, _socksProxyPort);
    } else {
        SRDebugLog(@"configureProxy no proxies");
    }
}

- (void)_fetchPAC:(NSURL *)PACurl withProxySettings:(NSDictionary *)proxySettings
{
    SRDebugLog(@"SRWebSocket fetchPAC:%@", PACurl);

    if ([PACurl isFileURL]) {
        NSError *error = nil;
        NSString *script = [NSString stringWithContentsOfURL:PACurl
                                                usedEncoding:NULL
                                                       error:&error];

        if (error) {
            [self _openConnection];
        } else {
            [self _runPACScript:script withProxySettings:proxySettings];
        }
        return;
    }

    NSString *scheme = [PACurl.scheme lowercaseString];
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) {
        // Don't know how to read data from this URL, we'll have to give up
        // We'll simply assume no proxies, and start the request as normal
        [self _openConnection];
        return;
    }
    __weak typeof(self) wself = self;
    NSURLRequest *request = [NSURLRequest requestWithURL:PACurl];
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        __strong typeof(wself) sself = wself;
        if (!error) {
            NSString *script = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            [sself _runPACScript:script withProxySettings:proxySettings];
        } else {
            [sself _openConnection];
        }
    }] resume];
}

- (void)_runPACScript:(NSString *)script withProxySettings:(NSDictionary *)proxySettings
{
    if (!script) {
        [self _openConnection];
        return;
    }
    SRDebugLog(@"runPACScript");
    // From: http://developer.apple.com/samplecode/CFProxySupportTool/listing1.html
    // Work around <rdar://problem/5530166>.  This dummy call to
    // CFNetworkCopyProxiesForURL initialise some state within CFNetwork
    // that is required by CFNetworkCopyProxiesForAutoConfigurationScript.
    CFBridgingRelease(CFNetworkCopyProxiesForURL((__bridge CFURLRef)_url, (__bridge CFDictionaryRef)proxySettings));

    // Obtain the list of proxies by running the autoconfiguration script
    CFErrorRef err = NULL;

    // CFNetworkCopyProxiesForAutoConfigurationScript doesn't understand ws:// or wss://
    NSURL *httpURL;
    if (_connectionRequiresSSL)
        httpURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@", _url.host]];
    else
        httpURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", _url.host]];

    NSArray *proxies = CFBridgingRelease(CFNetworkCopyProxiesForAutoConfigurationScript((__bridge CFStringRef)script,(__bridge CFURLRef)httpURL, &err));
    if (!err && [proxies count] > 0) {
        NSDictionary *settings = [proxies objectAtIndex:0];
        NSString *proxyType = settings[(NSString *)kCFProxyTypeKey];
        [self _readProxySettingWithType:proxyType settings:settings];
    }
    [self _openConnection];
}

- (void)_openConnection
{
    [self _initializeStreams];

    [self.inputStream scheduleInRunLoop:[NSRunLoop SR_networkRunLoop]
                                forMode:NSDefaultRunLoopMode];
    //[self.outputStream scheduleInRunLoop:[NSRunLoop SR_networkRunLoop]
    //                           forMode:NSDefaultRunLoopMode];
    [self.outputStream open];
    [self.inputStream open];
}

- (void)_initializeStreams
{
    assert(_url.port.unsignedIntValue <= UINT32_MAX);
    uint32_t port = _url.port.unsignedIntValue;
    if (port == 0) {
        port = (_connectionRequiresSSL ? 443 : 80);
    }
    NSString *host = _url.host;

    if (_httpProxyHost) {
        host = _httpProxyHost;
        port = (_httpProxyPort ?: 80);
    }

    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;

    SRDebugLog(@"ProxyConnect connect stream to %@:%u", host, port);
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)host, port, &readStream, &writeStream);

    self.outputStream = CFBridgingRelease(writeStream);
    self.inputStream = CFBridgingRelease(readStream);

    if (_socksProxyHost) {
        SRDebugLog(@"ProxyConnect set sock property stream to %@:%u user %@ password %@", _socksProxyHost, _socksProxyPort, _socksProxyUsername, _socksProxyPassword);
        NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:4];
        settings[NSStreamSOCKSProxyHostKey] = _socksProxyHost;
        if (_socksProxyPort) {
            settings[NSStreamSOCKSProxyPortKey] = @(_socksProxyPort);
        }
        if (_socksProxyUsername) {
            settings[NSStreamSOCKSProxyUserKey] = _socksProxyUsername;
        }
        if (_socksProxyPassword) {
            settings[NSStreamSOCKSProxyPasswordKey] = _socksProxyPassword;
        }
        [self.inputStream setProperty:settings forKey:NSStreamSOCKSProxyConfigurationKey];
        [self.outputStream setProperty:settings forKey:NSStreamSOCKSProxyConfigurationKey];
    }
    self.inputStream.delegate = self;
    self.outputStream.delegate = self;
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    SRDebugLog(@"stream handleEvent %u", eventCode);
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            if (aStream == self.inputStream) {
                if (_httpProxyHost) {
                    [self _proxyDidConnect];
                } else {
                    [self _didConnect];
                }
            }
        }  break;
        case NSStreamEventErrorOccurred: {
            [self _failWithError:aStream.streamError];
        } break;
        case NSStreamEventEndEncountered: {
            [self _failWithError:aStream.streamError];
        } break;
        case NSStreamEventHasBytesAvailable: {
            if (aStream == _inputStream) {
                [self _processInputStream];
            }
        } break;
        case NSStreamEventHasSpaceAvailable:
        case NSStreamEventNone:
            SRDebugLog(@"(default)  %@", aStream);
            break;
    }
}

- (void)_proxyDidConnect
{
    SRDebugLog(@"Proxy Connected");
    uint32_t port = _url.port.unsignedIntValue;
    if (port == 0) {
        port = (_connectionRequiresSSL ? 443 : 80);
    }
    // Send HTTP CONNECT Request
    NSString *connectRequestStr = [NSString stringWithFormat:@"CONNECT %@:%u HTTP/1.1\r\nHost: %@\r\nConnection: keep-alive\r\nProxy-Connection: keep-alive\r\n\r\n", _url.host, port, _url.host];

    NSData *message = [connectRequestStr dataUsingEncoding:NSUTF8StringEncoding];
    SRDebugLog(@"Proxy sending %@", connectRequestStr);

    [self _writeData:message];
}

///handles the incoming bytes and sending them to the proper processing method
- (void)_processInputStream
{
    NSMutableData *buf = [NSMutableData dataWithCapacity:SRDefaultBufferSize()];
    uint8_t *buffer = buf.mutableBytes;
    NSInteger length = [_inputStream read:buffer maxLength:SRDefaultBufferSize()];

    if (length <= 0) {
        return;
    }

    BOOL process = (_inputQueue.count == 0);
    [_inputQueue addObject:[NSData dataWithBytes:buffer length:length]];

    if (process) {
        [self _dequeueInput];
    }
}

// dequeue the incoming input so it is processed in order

- (void)_dequeueInput
{
    while (_inputQueue.count > 0) {
        NSData *data = _inputQueue.firstObject;
        [_inputQueue removeObjectAtIndex:0];

        // No need to process any data further, we got the full header data.
        if ([self _proxyProcessHTTPResponseWithData:data]) {
            break;
        }
    }
}
//handle checking the proxy  connection status
- (BOOL)_proxyProcessHTTPResponseWithData:(NSData *)data
{
    if (_receivedHTTPHeaders == NULL) {
        _receivedHTTPHeaders = CFHTTPMessageCreateEmpty(NULL, NO);
    }

    CFHTTPMessageAppendBytes(_receivedHTTPHeaders, (const UInt8 *)data.bytes, data.length);
    if (CFHTTPMessageIsHeaderComplete(_receivedHTTPHeaders)) {
        SRDebugLog(@"Finished reading headers %@", CFBridgingRelease(CFHTTPMessageCopyAllHeaderFields(_receivedHTTPHeaders)));
        [self _proxyHTTPHeadersDidFinish];
        return YES;
    }

    return NO;
}

- (void)_proxyHTTPHeadersDidFinish
{
    NSInteger responseCode = CFHTTPMessageGetResponseStatusCode(_receivedHTTPHeaders);

    if (responseCode >= 299) {
        SRDebugLog(@"Connect to Proxy Request failed with response code %d", responseCode);
        NSError *error = SRHTTPErrorWithCodeDescription(responseCode, 2132,
                                                        [NSString stringWithFormat:@"Received bad response code from proxy server: %d.",
                                                         (int)responseCode]);
        [self _failWithError:error];
        return;
    }
    SRDebugLog(@"proxy connect return %d, call socket connect", responseCode);
    [self _didConnect];
}

static NSTimeInterval const SRProxyConnectWriteTimeout = 5.0;

- (void)_writeData:(NSData *)data
{
    const uint8_t * bytes = data.bytes;
    __block NSInteger timeout = (NSInteger)(SRProxyConnectWriteTimeout * 1000000); // wait timeout before giving up
    __weak typeof(self) wself = self;
    dispatch_async(_writeQueue, ^{
        __strong typeof(wself) sself = self;
        if (!sself) {
            return;
        }
        NSOutputStream *outStream = sself.outputStream;
        if (!outStream) {
            return;
        }
        while (![outStream hasSpaceAvailable]) {
            usleep(100); //wait until the socket is ready
            timeout -= 100;
            if (timeout < 0) {
                NSError *error = SRHTTPErrorWithCodeDescription(408, 2132, @"Proxy timeout");
                [sself _failWithError:error];
            } else if (outStream.streamError != nil) {
                [sself _failWithError:outStream.streamError];
            }
        }
        [outStream write:bytes maxLength:data.length];
    });
}

@end
