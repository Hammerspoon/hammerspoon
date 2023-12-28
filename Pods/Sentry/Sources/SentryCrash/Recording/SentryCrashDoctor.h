// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashDoctor.h
//  SentryCrash
//
//  Created by Karl Stenerud on 2012-11-10.
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SentryCrashDoctor : NSObject

+ (SentryCrashDoctor *)doctor;

- (NSString *)diagnoseCrash:(NSDictionary *)crashReport;

@end
