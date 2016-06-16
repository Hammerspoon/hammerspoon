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

typedef NS_ENUM(NSInteger, PSWebSocketMode) {
    PSWebSocketModeClient = 0,
    PSWebSocketModeServer
};

typedef NS_ENUM(NSInteger, PSWebSocketErrorCodes) {
    PSWebSocketErrorCodeUnknown = 0,
    PSWebSocketErrorCodeTimedOut,
    PSWebSocketErrorCodeHandshakeFailed,
    PSWebSocketErrorCodeConnectionFailed
};

typedef NS_ENUM(NSInteger, PSWebSocketStatusCode) {
    PSWebSocketStatusCodeNormal = 1000,
    PSWebSocketStatusCodeGoingAway = 1001,
    PSWebSocketStatusCodeProtocolError = 1002,
    PSWebSocketStatusCodeUnhandledType = 1003,
    // 1004 reserved
    PSWebSocketStatusCodeNoStatusReceived = 1005,
    // 1006 reserved
    PSWebSocketStatusCodeInvalidUTF8 = 1007,
    PSWebSocketStatusCodePolicyViolated = 1008,
    PSWebSocketStatusCodeMessageTooBig = 1009
};

#define PSWebSocketGUID @"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
#define PSWebSocketErrorDomain @"PSWebSocketErrorDomain"

// NSError userInfo keys, used with PSWebSocketErrorCodeHandshakeFailed:
#define PSHTTPStatusErrorKey @"HTTPStatus"      // The HTTP status (404, etc.)
#define PSHTTPResponseErrorKey @"HTTPResponse"  // The entire HTTP response as an CFHTTPMessageRef
