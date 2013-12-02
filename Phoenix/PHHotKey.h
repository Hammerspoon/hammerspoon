//
//  PHHotKeyHandler.h
//  Phoenix
//
//  Created by Steven Degutis on 12/1/13.
//  Copyright (c) 2013 Steven. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PHHotKey;

typedef BOOL(^PHHotKeyHandler)(PHHotKey*);

@interface PHHotKey : NSObject

+ (void) setup;

@property NSString* key;
@property NSArray* mods;
@property (copy) PHHotKeyHandler handler;

+ (PHHotKey*) withKey:(NSString*)key mods:(NSArray*)mods handler:(PHHotKeyHandler)handler;

- (BOOL) enable;
- (void) disable;

@end
