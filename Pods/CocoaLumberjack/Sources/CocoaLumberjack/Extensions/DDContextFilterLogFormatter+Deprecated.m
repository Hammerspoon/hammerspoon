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

#import <CocoaLumberjack/DDContextFilterLogFormatter+Deprecated.h>

@implementation DDContextAllowlistFilterLogFormatter (Deprecated)

- (void)addToWhitelist:(NSInteger)loggingContext {
    [self addToAllowlist:loggingContext];
}

- (void)removeFromWhitelist:(NSInteger)loggingContext {
    [self removeFromAllowlist:loggingContext];
}

- (NSArray *)whitelist {
    return [self allowlist];
}

- (BOOL)isOnWhitelist:(NSInteger)loggingContext {
    return [self isOnAllowlist:loggingContext];
}

@end


@implementation DDContextDenylistFilterLogFormatter (Deprecated)

- (void)addToBlacklist:(NSInteger)loggingContext {
    [self addToDenylist:loggingContext];
}

- (void)removeFromBlacklist:(NSInteger)loggingContext {
    [self removeFromDenylist:loggingContext];
}

- (NSArray *)blacklist {
    return [self denylist];
}

- (BOOL)isOnBlacklist:(NSInteger)loggingContext {
    return [self isOnDenylist:loggingContext];
}

@end
