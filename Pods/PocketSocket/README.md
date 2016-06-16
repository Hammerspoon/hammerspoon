PocketSocket
============

Objective-C websocket library for building things that work in realtime on iOS and OS X.

### Features

* Conforms fully to [RFC6455](http://tools.ietf.org/html/rfc6455) websocket protocol
* Support for websocket compression via the [permessage-deflate](http://tools.ietf.org/html/draft-ietf-hybi-permessage-compression-17) extension
* Passes all ~519 Autobahn [Client Tests](http://zwopple.github.io/PocketSocket/results/client/) & [Server Tests](http://zwopple.github.io/PocketSocket/results/server/) with 100% compliance<sup>1</sup>
* Client & Server modes (see notes below)
* TLS/SSL support
* Asynchronous IO
* Standalone `PSWebSocketDriver` for easy “Bring your own” networking IO

> <sup>1</sup>Some server tests are non-strict and drop connections earlier when receiving malformed WebSocket payloads.

### Dependencies

* CFNetworking.framework
* Foundation.framework
* Security.framework
* libSystem.dylib
* libz.dylib

### Installation 

Installation is recommended via cocoapods. Add `pod 'PocketSocket'` to your Podfile and run `pod install`.

### Major Components

* **`PSWebSocketDriver`** - Networkless driver to deal with the websocket protocol. It solely operates with parsing raw bytes into events and sending events as raw bytes.
* **`PSWebSocket`** - Networking based socket around `NSInputStream` and `NSOutputStream` deals with ensuring a connection is maintained. Uses the `PSWebSocketDriver` internally on the input and output. 
* **`PSWebSocketServer`** - Networking based socket server around `CFSocket`. It creates one PSWebSocket instance per incoming request.

### Using PSWebSocket as a client

The client supports both the `ws` and secure `wss` protocols. It will automatically negotiate the certificates for you from the certificate chain on the device it’s running. If you need custom SSL certificate support or pinning look at the `webSocket:evaluateServerTrust:` in `PSWebSocketDelegate`

The client will always request the server turn on compression via the permessage-deflate extension. If the server accepts the request it will be enabled for the entire duration of the connection and used on all messages.

If the initial `NSURLRequest` specifies a timeout greater than 0 the connection will timeout if it cannot open within that interval, otherwise it could wait forever depending on the system.


```objc
#import <PSWebSocket/PSWebSocket.h>

@interface AppDelegate() <PSWebSocketDelegate>

@property (nonatomic, strong) PSWebSocket *socket;

@end
@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    // create the NSURLRequest that will be sent as the handshake
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"wss://example.com"]];
    
    // create the socket and assign delegate
    self.socket = [PSWebSocket clientSocketWithRequest:request];
    self.socket.delegate = self;
    
    // open socket
    [self.socket open];
    
    return YES;
}

#pragma mark - PSWebSocketDelegate

- (void)webSocketDidOpen:(PSWebSocket *)webSocket {
    NSLog(@"The websocket handshake completed and is now open!");
    [webSocket send:@"Hello world!"];
}
- (void)webSocket:(PSWebSocket *)webSocket didReceiveMessage:(id)message {
    NSLog(@"The websocket received a message: %@", message);
}
- (void)webSocket:(PSWebSocket *)webSocket didFailWithError:(NSError *)error {
    NSLog(@"The websocket handshake/connection failed with an error: %@", error);
}
- (void)webSocket:(PSWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    NSLog(@"The websocket closed with code: %@, reason: %@, wasClean: %@", @(code), reason, (wasClean) ? @"YES" : @"NO");
}

@end

```

### Using PSWebSocket via PSWebSocketServer

The server currently only supports the `ws` protocol. The server binds to the host address and port specified and accepts incoming connections. It parses the first HTTP request in each connection and then asks the delegate whether or not to accept it and complete the websocket handshake. The server expects to remain the delegate of all `PSWebSocket` instances it manages so be careful not to manage them yourself or detach them from the server.


```objc
#import <PSWebSocket/PSWebSocketServer.h>

@interface AppDelegate() <PSWebSocketServerDelegate>

@property (nonatomic, strong) PSWebSocketServer *server;

@end
@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    _server = [PSWebSocketServer serverWithHost:nil port:9001];
    _server.delegate = self;
    [_server start];
}

#pragma mark - PSWebSocketServerDelegate

- (void)serverDidStart:(PSWebSocketServer *)server {
    NSLog(@"Server did start…");
}
- (void)serverDidStop:(PSWebSocketServer *)server {
    NSLog(@"Server did stop…");
}
- (BOOL)server:(PSWebSocketServer *)server acceptWebSocketWithRequest:(NSURLRequest *)request {
    NSLog(@"Server should accept request: %@", request);
    return YES;
}
- (void)server:(PSWebSocketServer *)server webSocket:(PSWebSocket *)webSocket didReceiveMessage:(id)message {
    NSLog(@"Server websocket did receive message: %@", message);
}
- (void)server:(PSWebSocketServer *)server webSocketDidOpen:(PSWebSocket *)webSocket {
    NSLog(@"Server websocket did open");
}
- (void)server:(PSWebSocketServer *)server webSocket:(PSWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    NSLog(@"Server websocket did close with code: %@, reason: %@, wasClean: %@", @(code), reason, @(wasClean));
}
- (void)server:(PSWebSocketServer *)server webSocket:(PSWebSocket *)webSocket didFailWithError:(NSError *)error {
    NSLog(@"Server websocket did fail with error: %@", error);
}

@end
```


### Using PSWebSocketDriver

The driver is the core of `PSWebSocket`. It deals with the handshake request/response lifecycle, packing messages into websocket frames to be sent over the wire and parsing websocket frames received over the wire.

It supports both client and server mode and has an identical API for each.

To create an instance of it you use either `clientDriverWithRequest:` or `serverDriverWithRequest:` in the client mode you are to pass in a `NSURLRequest` that will be sent as a handshake request. In server mode you are to pass in the `NSURLRequest` that was the handshake request.

Beyond that have a look at the `PSWebSocketDriverDelegate` methods and the simple API for interacting with the driver.


### Roadmap

* Examples, examples, examples!

### Running Tests

1. Install autobahntestsuite `sudo pip install autobahntestsuite`
2. Start autobahn test server `wstest -m fuzzingserver`
3. Run tests in Xcode

### Why a new library?

Currently for Objective-C there is few options for websocket clients. SocketRocket, while probably the most notable, has a code base being entirely contained in a single file and proved difficult to build in new features such as permessage-deflate and connection timeouts. 

PocketSocket firstly aims to provide a rich set of tools that are easy to dig into and modify when necessary. The decoupling of the network layer from the driver layer allows a lot of flexibility to incorporate the library with existing setups.

Secondly we intend on keeping PocketSocket at the top of it's game. As soon as any major websocket extensions come into play you can count on them being incorporated as soon as the drafts begin to stabalize.

Lastly we're set out to create the full picture from client to server all in a single, but decoupled toolkit for all use cases on iOS and OS X.



### Authors

* Robert Payne (@robertjpayne)

### Contributors

* Jens Alfke (@snej)

### License

Copyright 2014-Present Zwopple Limited

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
