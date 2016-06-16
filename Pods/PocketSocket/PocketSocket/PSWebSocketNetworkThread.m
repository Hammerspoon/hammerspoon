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

#import "PSWebSocketNetworkThread.h"

@interface PSWebSocketNetworkThread() {
    dispatch_group_t _waitGroup;
}

@property (nonatomic, strong) NSRunLoop *runLoop;

@end
@implementation PSWebSocketNetworkThread

#pragma mark - Singleton

+ (instancetype)sharedNetworkThread {
	static id sharedNetworkThread = nil;
	static dispatch_once_t sharedNetworkThreadOnce = 0;
	dispatch_once(&sharedNetworkThreadOnce, ^{
		sharedNetworkThread = [[self alloc] init];
	});
	return sharedNetworkThread;
}

#pragma mark - Properties

- (NSRunLoop *)runLoop {
    dispatch_group_wait(_waitGroup, DISPATCH_TIME_FOREVER);
    return _runLoop;
}

#pragma mark - Initialization

- (instancetype)init {
	if((self = [super init])) {
		_waitGroup = dispatch_group_create();
        dispatch_group_enter(_waitGroup);
        
        [self start];
	}
	return self;
}
- (void)main {
    @autoreleasepool {
        _runLoop = [NSRunLoop currentRunLoop];
        dispatch_group_leave(_waitGroup);
        
        NSTimer *timer = [[NSTimer alloc] initWithFireDate:[NSDate distantFuture] interval:0.0 target:self selector:@selector(self) userInfo:nil repeats:NO];
        [_runLoop addTimer:timer forMode:NSDefaultRunLoopMode];
        
        NSRunLoop *runLoop = _runLoop;
        while([runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]) {
            // no-op
        }
        [NSException raise:NSInternalInconsistencyException format:@"PSWebSocketNetworkThread should never exit."];
    }
}


@end
