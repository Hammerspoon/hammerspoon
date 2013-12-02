//
//  PHAPI.h
//  Phoenix
//
//  Created by Steven on 12/2/13.
//  Copyright (c) 2013 Steven. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <JavaScriptCore/JavaScriptCore.h>
#import "PHHotKey.h"

@protocol SeriouslyAppleQuestionMarkSeriouslyQuestionMark <JSExport>

- (PHHotKey*) withKey:(NSString*)key mods:(NSArray*)mods handler:(JSValue*)handler;
- (void) log:(NSString*)str;

@end

@interface PHAPI : NSObject <SeriouslyAppleQuestionMarkSeriouslyQuestionMark>

@end
