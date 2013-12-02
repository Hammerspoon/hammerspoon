//
//  PHAPI.m
//  Phoenix
//
//  Created by Steven on 12/2/13.
//  Copyright (c) 2013 Steven. All rights reserved.
//

#import "PHAPI.h"

@implementation PHAPI

- (PHHotKey*) withKey:(NSString*)key mods:(NSArray*)mods handler:(JSValue*)handler {
    NSLog(@"registering.");
    return [PHHotKey withKey:key mods:mods handler:^BOOL(PHHotKey* hotkey) {
        NSLog(@"getting called.");
        return [[handler callWithArguments:@[hotkey]] toBool];
    }];
}

- (void) log:(NSString*)str {
    NSLog(@"%@", str);
}

@end
