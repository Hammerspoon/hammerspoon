// Software License Agreement (BSD License)
//
// Copyright (c) 2010-2021, Deusty, LLC
// All rights reserved.
//
// Redistribution and use of this software in source and binary forms,
// with or without modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
//
// * Neither the name of Deusty nor the names of its contributors may be used
//   to endorse or promote products derived from this software without specific
//   prior written permission of Deusty, LLC.

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import <pthread/pthread.h>

#import <CocoaLumberjack/DDContextFilterLogFormatter.h>

@interface DDLoggingContextSet : NSObject

@property (readonly, copy, nonnull) NSArray *currentSet;

- (void)addToSet:(NSInteger)loggingContext;
- (void)removeFromSet:(NSInteger)loggingContext;

- (BOOL)isInSet:(NSInteger)loggingContext;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface DDContextAllowlistFilterLogFormatter () {
    DDLoggingContextSet *_contextSet;
}
@end

@implementation DDContextAllowlistFilterLogFormatter

- (instancetype)init {
    if ((self = [super init])) {
        _contextSet = [[DDLoggingContextSet alloc] init];
    }
    return self;
}

- (void)addToAllowlist:(NSInteger)loggingContext {
    [_contextSet addToSet:loggingContext];
}

- (void)removeFromAllowlist:(NSInteger)loggingContext {
    [_contextSet removeFromSet:loggingContext];
}

- (NSArray *)allowlist {
    return [_contextSet currentSet];
}

- (BOOL)isOnAllowlist:(NSInteger)loggingContext {
    return [_contextSet isInSet:loggingContext];
}

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage {
    if ([self isOnAllowlist:logMessage->_context]) {
        return logMessage->_message;
    } else {
        return nil;
    }
}

@end


@interface DDContextDenylistFilterLogFormatter () {
    DDLoggingContextSet *_contextSet;
}
@end

@implementation DDContextDenylistFilterLogFormatter

- (instancetype)init {
    if ((self = [super init])) {
        _contextSet = [[DDLoggingContextSet alloc] init];
    }
    return self;
}

- (void)addToDenylist:(NSInteger)loggingContext {
    [_contextSet addToSet:loggingContext];
}

- (void)removeFromDenylist:(NSInteger)loggingContext {
    [_contextSet removeFromSet:loggingContext];
}

- (NSArray *)denylist {
    return [_contextSet currentSet];
}

- (BOOL)isOnDenylist:(NSInteger)loggingContext {
    return [_contextSet isInSet:loggingContext];
}

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage {
    if ([self isOnDenylist:logMessage->_context]) {
        return nil;
    } else {
        return logMessage->_message;
    }
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface DDLoggingContextSet () {
    pthread_mutex_t _mutex;
    NSMutableSet *_set;
}
@end

@implementation DDLoggingContextSet

- (instancetype)init {
    if ((self = [super init])) {
        _set = [[NSMutableSet alloc] init];
        pthread_mutex_init(&_mutex, NULL);
    }

    return self;
}

- (void)dealloc {
    pthread_mutex_destroy(&_mutex);
}

- (void)addToSet:(NSInteger)loggingContext {
    pthread_mutex_lock(&_mutex);
    {
        [_set addObject:@(loggingContext)];
    }
    pthread_mutex_unlock(&_mutex);
}

- (void)removeFromSet:(NSInteger)loggingContext {
    pthread_mutex_lock(&_mutex);
    {
        [_set removeObject:@(loggingContext)];
    }
    pthread_mutex_unlock(&_mutex);
}

- (NSArray *)currentSet {
    NSArray *result = nil;

    pthread_mutex_lock(&_mutex);
    {
        result = [_set allObjects];
    }
    pthread_mutex_unlock(&_mutex);

    return result;
}

- (BOOL)isInSet:(NSInteger)loggingContext {
    BOOL result = NO;

    pthread_mutex_lock(&_mutex);
    {
        result = [_set containsObject:@(loggingContext)];
    }
    pthread_mutex_unlock(&_mutex);

    return result;
}

@end
