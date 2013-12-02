//
//  MyUniversalAccessHelper.m
//  Zephyros
//
//  Created by Steven Degutis on 3/1/13.
//  Copyright (c) 2013 Steven Degutis. All rights reserved.
//

#import "PHUniversalAccessHelper.h"

@implementation PHUniversalAccessHelper

+ (BOOL) complainIfNeeded {
    static BOOL shouldAsk = YES;
    
    BOOL enabled = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge id)kAXTrustedCheckOptionPrompt: @(shouldAsk)});
    
    if (shouldAsk) {
        shouldAsk = NO;
        double delayInSeconds = 5.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            shouldAsk = YES;
        });
    }
    
    return !enabled;
}

@end
